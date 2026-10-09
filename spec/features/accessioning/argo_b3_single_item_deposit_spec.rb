# frozen_string_literal: true

# Integration: Argo-B3, DSA, Purl, Stacks
RSpec.describe 'Use Argo-B3 to register and deposit a single item', type: :accessioning do
  let(:start_url) { Settings.argo_b3_url }
  let(:title) { "argo-b3 single item deposit #{random_phrase}" }
  let(:filenames) { ['example.tiff', 'stanford-logo.tiff'] }

  before do
    authenticate!(start_url:, expected_text: 'Argo dashboard')
  end

  scenario do
    ## Step 1: Register the item
    click_button 'Item', exact: true
    expect(page).to have_css('h1', text: 'Register an item')

    # Item details tab
    select 'image', from: 'Content type'
    choose 'Enter prefix to autogenerate source ID'
    fill_in 'Source ID prefix', with: 'integration'
    click_button 'Next'

    # Description tab
    fill_in 'Title', with: title
    click_button 'Next'

    # APO, collection, rights tab
    find(:select, 'APO').find("option[value='#{Settings.default_apo}']").select_option

    # Register tab
    find_by_id('deposit-tab').click
    click_button 'Register and add files'

    ## Step 2: Upload files
    expect(page).to have_css('h1', text: 'Manage files')
    druid = page.current_url[/druid:[b-df-hjkmnp-tv-z]{2}[0-9]{3}[b-df-hjkmnp-tv-z]{2}[0-9]{4}/]
    puts " *** argo-b3 single item deposit druid: #{druid} ***"

    attach_file(nil, filenames.map { |filename| "spec/fixtures/#{filename}" }, class: 'dz-hidden-input', make_visible: true)
    filenames.each { |filename| expect(page).to have_css('tbody th', text: filename) }

    ## Step 3: Structure files
    find_by_id('structural-tab').click
    click_button 'Structure files'
    expect(page).to have_css('h3', text: 'Structural metadata')

    ## Step 4: Deposit
    find_by_id('deposit-tab').click
    # The Deposit tab is also a button, so match exactly; this also waits for the button to be enabled.
    click_button 'Deposit', exact: true
    expect(page).to have_css('h1', text: title)
    # The show page refreshes itself as the deposit progresses.
    expect(page).to have_css('h2', text: 'Deposited', wait: Settings.timeouts.workflow)

    ## Step 5: Find the item by searching
    fill_in 'Search for', with: title
    click_button 'Search'
    # Wait for the item to be indexed.
    reload_page_until_timeout! { page.has_css?('caption a', text: title, wait: 1) }
    find('caption a', text: title).click
    expect(page).to have_css('h1', text: title)

    ## Step 6: Verify published to PURL with an accessible IIIF image
    purl_window = window_opened_by { click_link 'View PURL page' }
    within_window(purl_window) do
      # Wait for the item to be published.
      reload_page_until_timeout!(text: title)
      expect(page).to have_text(title)

      iiif_manifest_url = find(:xpath, '//link[@rel="alternate" and @title="IIIF Manifest"]', visible: false)[:href]
      iiif_manifest = JSON.parse(Faraday.get(iiif_manifest_url).body)
      image_url = iiif_manifest.dig('sequences', 0, 'canvases', 0, 'images', 0, 'resource', '@id')
      puts "Checking that the image URL #{image_url} is accessible..."
      image_response = fetch_image_response(image_url)
      expect(image_response.status).to eq(200)
      expect(image_response.headers['content-type']).to include('image/jpeg')
    end
  end
end
