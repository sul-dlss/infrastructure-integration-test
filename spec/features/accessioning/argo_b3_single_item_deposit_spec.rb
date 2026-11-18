# frozen_string_literal: true

# Integration: Argo-B3, DSA, Purl, Stacks, Preservation
RSpec.describe 'Use Argo-B3 to register, deposit, redeposit, and darken a single item', type: :accessioning do
  let(:start_url) { Settings.argo_b3_url }
  let(:title) { "argo-b3 single item deposit #{random_phrase}" }
  let(:filenames) { ['example.tiff', 'stanford-logo.tiff'] }
  let(:new_title) { "argo-b3 single item redeposit #{random_phrase}" }
  let(:deleted_filenames) { ['stanford-logo.tiff', 'stanford-logo.jp2'] }
  let(:added_filename) { 'vision_for_stanford.jpg' }
  let(:v2_filenames) { ['example.tiff', added_filename] }
  # Accessioning's JP2 derivatives of the v2 images, which are shelved but not preserved.
  let(:derivative_filenames) { ['example.jp2', 'vision_for_stanford.jp2'] }
  let(:version_description) { "argo-b3 single item redeposit #{random_phrase}" }
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

    expect_manage_files_step('Item details')
    click_button 'Next'
    expect_manage_files_step('Add and edit files')
    attach_file(nil, filenames.map { |filename| "spec/fixtures/#{filename}" }, class: 'dz-hidden-input', make_visible: true)
    filenames.each { |filename| expect(page).to have_css('tbody th', text: filename) }

    ## Step 3: Structure files
    structure_files_from_files_step
    expect(page).to have_text('Files were structured with the Image (resource per image) model.')
    expect(page).to have_css('h3', exact_text: 'Resources (2)')

    ## Step 4: Deposit
    deposit_from_manage_files
    expect(page).to have_css('h1', text: title)
    # The show page refreshes itself as the deposit progresses.
    expect(page).to have_css('h2', text: 'Deposited', wait: Settings.timeouts.workflow)

    ## Step 5: Verify technical metadata
    find_by_id('files-tab').click
    # A deposited file's View button shows its technical metadata below it, lazily loaded.
    click_button 'View technical metadata for example.tiff'
    # The techmd turbo-frame only fetches its content once it is scrolled into the
    # viewport, since it uses loading="lazy".
    technical_metadata = find('tbody td .collapse.show')
    page.scroll_to(technical_metadata)
    # Scoped to the techmd frame since the file row also shows the MIME type.
    within(technical_metadata.find('turbo-frame')) do
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
    # Tabs with required fields name them in visually hidden text, so find by id.
    find_by_id('description-tab').click
    click_link 'Download description spreadsheet'
    wait_for_download
    description_csv = CSV.read(download, headers: true)
    expect(description_csv.first['title1.value']).to eq(title)
    description_csv.first['title1.value'] = new_title
    File.write(description_csv_path, description_csv.to_csv)
    attach_file 'Upload a CSV file', File.absolute_path(description_csv_path)

    # Saving opens a new version, with the files still to be changed before depositing.
    find_by_id('deposit-tab').click
    fill_in 'Version description', with: version_description
    click_button 'Save draft and edit files'

    ## Step 9: Delete a file, add a file, and redeposit
    expect(page).to have_css('h1', text: 'Manage files')
    expect_manage_files_step('Item details')
    click_button 'Next'
    expect_manage_files_step('Add and edit files')
    # Accessioning added a JP2 derivative to the resource, so only deleting the JP2 too empties (and deletes) it.
    click_button "Delete #{deleted_filenames.first}"
    expect(page).to have_no_css('tbody th', exact_text: deleted_filenames.first)
    accept_confirm(/will also delete resource/) { click_button "Delete #{deleted_filenames.last}" }
    expect(page).to have_no_css('tbody th', exact_text: deleted_filenames.last)
    attach_file(nil, "spec/fixtures/#{added_filename}", class: 'dz-hidden-input', make_visible: true)
    expect(page).to have_css('tbody th', text: added_filename)

    # Leaving the files step appends the added file to the structure.
    structure_files_from_files_step
    expect(page).to have_css('h3', exact_text: 'Resources (2)')

    deposit_from_manage_files(version_description:)
    expect(page).to have_css('h1', text: new_title)
    expect(page).to have_css('h2', text: 'Deposited', wait: Settings.timeouts.workflow)

    ## Step 10: Verify the redeposit in Argo-B3 and on PURL
    expect_files_on_object_page(druid:, filenames: v2_filenames, absent_filenames: deleted_filenames)

    published_filenames = published_cocina_filenames(druid:, version: 2)
    # Only the JP2 derivatives of images are published.
    expect(published_filenames).to match_array(derivative_filenames)
    # One canvas per resource.
    iiif_manifest = JSON.parse(Faraday.get("#{Settings.purl_url}/#{bare_druid(druid)}/iiif/manifest").body)
    expect(iiif_manifest.dig('sequences', 0, 'canvases').size).to eq(2)

    expect_text_on_purl_page(druid:, text: new_title)
    expect(page).to have_no_text(title)

    ## Step 11: Download all files, from Preservation and Stacks
    zipped_files = download_all_files(druid:)
    expect(zipped_files.keys).to contain_exactly(*v2_filenames, *derivative_filenames)
    # Preserved only, so from Preservation.
    v2_filenames.each { |filename| expect(zipped_files[filename]).to eq(File.binread("spec/fixtures/#{filename}")) }
    # Shelved only, so from Stacks.
    expect(zipped_files.values_at(*derivative_filenames)).to all(be_present)

    ## Step 12: Make the item dark and redeposit
    visit "#{start_url}/objects/#{druid}"
    click_link 'Edit item'
    find_by_id('rights-tab').click
    select 'Dark', from: 'View access'
    # A dark item cannot have published files, so the file-level rights are always overwritten.
    expect(page).to have_field('Overwrite file-level rights', checked: true, disabled: true)

    find_by_id('deposit-tab').click
    fill_in 'Version description', with: "argo-b3 single item dark #{random_phrase}"
    click_button 'Deposit', type: 'submit'
    expect(page).to have_css('h1', text: new_title)
    expect(page).to have_css('h2', text: 'Deposited', wait: Settings.timeouts.workflow)

    ## Step 13: Verify removed from PURL
    expect_removed_from_purl(druid:)
  end
end
