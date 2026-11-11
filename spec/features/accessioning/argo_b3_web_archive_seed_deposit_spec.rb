# frozen_string_literal: true

# Integration: Argo-B3, DSA, SWAP (was-pywb), Purl
RSpec.describe 'Use Argo-B3 to register a web archive seed object', type: :accessioning do
  let(:start_url) { Settings.argo_b3_url }
  let(:collection_name) { 'Test Pywb Web Archive' }
  let(:start_time) { Time.now }
  let(:source_id) { "seed-test:#{start_time.to_i}" }
  let(:url_in_wayback) { 'https://library.stanford.edu/department/digital-library-systems-and-services-dlss/about-us' }
  let(:archived_url) { "#{Settings.was_playback_url}/*/#{url_in_wayback}" }

  before do
    authenticate!(start_url:, expected_text: 'Argo dashboard')
  end

  scenario do
    ## Register the web archive seed item
    click_button 'Item', exact: true
    expect(page).to have_css('h1', text: 'Register an item')

    # Item details tab
    select 'webarchive-seed', from: 'Content type'
    choose 'Enter source ID'
    fill_in 'Source ID', with: source_id
    click_button 'Next'

    # Description tab
    fill_in 'Title', with: url_in_wayback
    click_button 'Next'

    # APO, collection, rights tab
    select 'Web Archive Seed Object APO', from: 'APO'
    collection_input = find_field(placeholder: 'Start typing the collection name or druid...')
    collection_input.fill_in(with: collection_name)
    find('.ts-dropdown .option', text: collection_name).click
    expect(page).to have_css('.ts-control .item', text: collection_name)

    # Tags tab
    find_by_id('tags-tab').click
    fill_in 'Tag', with: 'webarchive : seed'

    # Register (no files to upload - content comes from the existing web archive crawl)
    find_by_id('deposit-tab').click
    click_button 'Register only'

    # Plain "Register only" redirects straight to the object show page. Wait for the URL itself to
    # change before reading the druid from it, rather than relying on page content as a proxy.
    expect(page).to have_current_path(%r{/objects/druid:[b-df-hjkmnp-tv-z]{2}[0-9]{3}[b-df-hjkmnp-tv-z]{2}[0-9]{4}})
    seed_druid = page.current_url[/druid:[b-df-hjkmnp-tv-z]{2}[0-9]{3}[b-df-hjkmnp-tv-z]{2}[0-9]{4}/]
    puts " *** argo-b3 web archive seed druid: #{seed_druid} ***"
    expect(page).to have_css('#overview-table tr', text: /Content type\s+Webarchive Seed/)

    # Depositing a draft with no files kicks off wasSeedPreassemblyWF.
    click_button 'Deposit'
    expect(page).to have_text('Deposit started.')

    reload_page_until_timeout! do
      # The Workflows tab doesn't render until a workflow exists for the object, so the very first
      # (unreloaded) pass may not have it yet; checking first avoids an unrescued ElementNotFound.
      next false unless page.has_css?('#workflows-tab', wait: 1)

      find_by_id('workflows-tab').click
      within('#workflows-pane') do
        page.has_css?('.collapsible-section-toggle', text: /wasSeedPreassemblyWF\s+Complete/, wait: 5)
      end
    end

    reload_page_until_timeout! { page.has_css?('#overview-table tr', text: /Status\s+v1 Accessioned/, wait: 1) }

    find_by_id('files-tab').click
    expect(page).to have_css('tbody th', text: 'thumbnail.jp2')

    # Confirms the cocina JSON has been published to PURL with the replay URL.
    # We sometimes need to wait for the PURL page to be ready, likely related to filesystem latency.
    # "Eventually" meaning roughly 9-10 minutes. To allow this test to pass,
    # wait a considerably longer time and print out messages so the developer
    # knows what's going on. Hopefully we can jettison this at some point.
    sleep_duration = 15
    counter = 0
    while counter <= 100
      json_url = "#{Settings.purl_url}/#{bare_druid(seed_druid)}.json"
      cocina_json_response = Faraday.get(json_url)
      puts "stacks json response at #{sleep_duration * counter}s: #{cocina_json_response.status}"

      break if cocina_json_response.status == 200

      counter += 1
      sleep sleep_duration
    end

    cocina_json = JSON.parse(cocina_json_response.body)
    access = cocina_json['description']['access']
    expect(access['url'].first['value']).to eq archived_url

    ## Replace the auto-generated thumbnail with a different file
    click_link_or_button 'Manage files'
    expect(page).to have_css('h1', text: 'Manage files')

    # Add files tab (the default tab)
    attach_file(nil, 'spec/fixtures/new-thumbnail.jp2', class: 'dz-hidden-input', make_visible: true)
    expect(page).to have_css('tbody th', text: 'new-thumbnail.jp2')

    # thumbnail.jp2 is the sole file in its resource, so deleting it also deletes that resource.
    accept_confirm(/will also delete resource/) { click_button 'Delete thumbnail.jp2' }
    expect(page).to have_no_css('tbody th', exact_text: 'thumbnail.jp2')

    # Structure tab
    find_by_id('structural-tab').click
    within('#structural-pane') do
      # The structure frame can briefly render twice while it reloads, so wait for a single stable button.
      expect(page).to have_button('Structure files', count: 1)
      click_button 'Structure files'
    end
    expect(page).to have_text('Structure built from files')

    # Deposit the new version
    find_by_id('deposit-tab').click
    fill_in 'Version description', with: 'Replace web archive seed thumbnail'
    click_button 'Deposit', exact: true
    # Reloading the edit page once the deposit has started redirects with an "Item is not editable." alert.
    expect(page).to have_current_path(%r{/objects/#{seed_druid}\z})

    reload_page_until_timeout! { page.has_css?('#overview-table tr', text: /Status\s+v2 Accessioned/, wait: 1) }

    # The new file's role was already set to thumbnail, and the title was unchanged, so both
    # thumbnail-generator and desc-metadata-generator should skip redoing their work.
    find_by_id('workflows-tab').click
    within('#workflows-pane') do
      find('.collapsible-section-toggle', text: /wasSeedPreassemblyWF/).click
      within(:table, 'wasSeedPreassemblyWF - Version 2') do
        desc_metadata_row = find(:xpath, ".//tr[./th[normalize-space()='desc-metadata-generator']]")
        puts " *** desc-metadata-generator row (v2): #{desc_metadata_row.text} ***"
        expect(desc_metadata_row).to have_css('td', text: 'Skipped')
        expect(desc_metadata_row).to have_text('Files are staged; keeping existing description')

        thumbnail_generator_row = find(:xpath, ".//tr[./th[normalize-space()='thumbnail-generator']]")
        puts " *** thumbnail-generator row (v2): #{thumbnail_generator_row.text} ***"
        expect(thumbnail_generator_row).to have_css('td', text: 'Skipped')
      end
    end

    # The replacement is the file in use, and a new thumbnail.jp2 was not created.
    find_by_id('files-tab').click
    expect(page).to have_css('tbody th', exact_text: 'new-thumbnail.jp2')
    expect(page).to have_no_css('tbody th', exact_text: 'thumbnail.jp2')
  end
end
