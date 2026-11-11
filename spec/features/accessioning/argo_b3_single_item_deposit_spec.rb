# frozen_string_literal: true

# Integration: Argo-B3, DSA, Purl, Stacks
RSpec.describe 'Use Argo-B3 to register, deposit, redeposit, and darken a single item', type: :accessioning do
  let(:start_url) { Settings.argo_b3_url }
  let(:title) { "argo-b3 single item deposit #{random_phrase}" }
  let(:filenames) { ['example.tiff', 'stanford-logo.tiff'] }
  let(:new_title) { "argo-b3 single item redeposit #{random_phrase}" }
  let(:deleted_filenames) { ['stanford-logo.tiff', 'stanford-logo.jp2'] }
  let(:added_filename) { 'vision_for_stanford.jpg' }
  let(:v2_filenames) { ['example.tiff', added_filename] }
  let(:description_csv_path) { 'tmp/argo_b3_single_item_description.csv' }

  before do
    clear_downloads
    authenticate!(start_url:, expected_text: 'Argo dashboard')
  end

  after do
    clear_downloads
    FileUtils.rm_f(description_csv_path)
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
    within('#structural-pane') do
      # The structure frame reloads after the upload; clicking before then is discarded.
      expect(page).to have_text('There are 2 files that have not been added to the structure.')
      click_button 'Structure files'
    end
    expect(page).to have_css('h3', text: 'Structural metadata')

    ## Step 4: Deposit
    find_by_id('deposit-tab').click
    # The Deposit tab is also a button, so match exactly; this also waits for the button to be enabled.
    click_button 'Deposit', exact: true
    expect(page).to have_css('h1', text: title)
    # The show page refreshes itself as the deposit progresses.
    expect(page).to have_css('h2', text: 'Deposited', wait: Settings.timeouts.workflow)

    ## Step 5: Verify technical metadata
    find_by_id('files-tab').click
    # Deposited file rows toggle a row that lazily loads the technical metadata.
    find('tr.toggle-row', text: 'example.tiff').click
    # The techmd turbo-frame only fetches its content once it is scrolled into the
    # viewport, since it uses loading="lazy".
    toggle_row_data = find('tr.toggle-row-data.show')
    page.scroll_to(toggle_row_data)
    # Scoped to the techmd frame since the file row also shows the MIME type.
    within(toggle_row_data.find('turbo-frame')) do
      expect(page).to have_css('dt', text: 'Mimetype')
      expect(page).to have_css('dd', text: 'image/tiff')
    end

    ## Step 6: Find the item by searching
    fill_in 'Search for', with: title
    click_button 'Search'
    # Wait for the item to be indexed.
    reload_page_until_timeout! { page.has_css?('caption a', text: title, wait: 1) }
    find('caption a', text: title).click
    expect(page).to have_css('h1', text: title)

    ## Step 7: Verify published to PURL with an accessible IIIF image
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

    ## Step 8: Change the title by downloading, editing, and uploading the description spreadsheet
    visit "#{start_url}/objects/#{druid}"
    click_link 'Edit item'
    expect(page).to have_css('h1', text: 'Edit item')
    click_button 'Description'
    click_link 'Download description spreadsheet'
    wait_for_download
    description_csv = CSV.read(download, headers: true)
    expect(description_csv.first['title1.value']).to eq(title)
    description_csv.first['title1.value'] = new_title
    File.write(description_csv_path, description_csv.to_csv)
    attach_file 'Upload a CSV file', File.absolute_path(description_csv_path)

    # Saving opens a new version, with the files still to be changed before depositing.
    find_by_id('deposit-tab').click
    fill_in 'Version description', with: "argo-b3 single item redeposit #{random_phrase}"
    click_button 'Save draft and edit files'

    ## Step 9: Delete a file, add a file, and redeposit
    expect(page).to have_css('h1', text: 'Manage files')
    # Accessioning added a JP2 derivative to the resource, so only deleting the JP2 too empties (and deletes) it.
    click_button "Delete #{deleted_filenames.first}"
    expect(page).to have_no_css('tbody th', exact_text: deleted_filenames.first)
    accept_confirm(/will also delete resource/) { click_button "Delete #{deleted_filenames.last}" }
    expect(page).to have_no_css('tbody th', exact_text: deleted_filenames.last)
    attach_file(nil, "spec/fixtures/#{added_filename}", class: 'dz-hidden-input', make_visible: true)
    expect(page).to have_css('tbody th', text: added_filename)

    find_by_id('structural-tab').click
    within('#structural-pane') do
      expect(page).to have_text('There is 1 file that has not been added to the structure.')
      click_button 'Append files to structure'
    end
    expect(page).to have_text('Files appended to structure')

    find_by_id('deposit-tab').click
    click_button 'Deposit', exact: true
    expect(page).to have_css('h1', text: new_title)
    expect(page).to have_css('h2', text: 'Deposited', wait: Settings.timeouts.workflow)

    ## Step 10: Verify the redeposit in Argo-B3 and on PURL
    expect_files_on_object_page(druid:, filenames: v2_filenames, absent_filenames: deleted_filenames)

    published_filenames = published_cocina_filenames(druid:, version: 2)
    # Only the JP2 derivatives of images are published.
    expect(published_filenames).to contain_exactly('example.jp2', 'vision_for_stanford.jp2')
    # One canvas per resource.
    iiif_manifest = JSON.parse(Faraday.get("#{Settings.purl_url}/#{bare_druid(druid)}/iiif/manifest").body)
    expect(iiif_manifest.dig('sequences', 0, 'canvases').size).to eq(2)

    expect_text_on_purl_page(druid:, text: new_title)
    expect(page).to have_no_text(title)

    ## Step 11: Make the item dark and redeposit
    visit "#{start_url}/objects/#{druid}"
    click_link 'Edit item'
    click_button 'APO, collection, rights'
    select 'Dark', from: 'View access'
    # A dark item cannot have published files, so the file-level rights are always overwritten.
    expect(page).to have_field('Overwrite file-level rights', checked: true, disabled: true)

    find_by_id('deposit-tab').click
    fill_in 'Version description', with: "argo-b3 single item dark #{random_phrase}"
    click_button 'Deposit', type: 'submit'
    expect(page).to have_css('h1', text: new_title)
    expect(page).to have_css('h2', text: 'Deposited', wait: Settings.timeouts.workflow)

    ## Step 12: Verify removed from PURL
    expect_removed_from_purl(druid:)
  end
end
