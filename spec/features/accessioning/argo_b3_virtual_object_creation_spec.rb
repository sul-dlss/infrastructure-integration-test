# frozen_string_literal: true

# Integration: Argo-B3, DSA, Purl
# The constituents' files are in folders on a mount that argo-b3 can read (Settings.argo_b3_virtual_object_directory).
# A multi-item deposit cannot share a folder between druids, so each of the two constituents has its own folder.
RSpec.describe 'Use Argo-B3 to create a virtual object with constituent objects', type: :accessioning do
  let(:start_url) { Settings.argo_b3_url }
  let(:run_id) { SecureRandom.uuid }
  let(:registration_csv_path) { 'tmp/argo_b3_virtual_object_registration.csv' }
  let(:virtual_object_csv_path) { 'tmp/argo_b3_virtual_object.csv' }
  # Each folder has one image file.
  let(:file_count) { 1 }
  # Titles keyed by folder.
  let(:constituents) do
    %w[image-1 image-2].index_with { "argo-b3 virtual object constituent #{random_phrase}" }
  end
  # Populated by registration, keyed like constituents.
  let(:druids) { {} }
  let(:virtual_object_title) { "argo-b3 virtual object #{random_phrase}" }
  let(:bulk_action_description) { "argo-b3 virtual object #{run_id}" }

  before do
    authenticate!(start_url:, expected_text: 'Argo dashboard')
  end

  after do
    FileUtils.rm_f(registration_csv_path)
    FileUtils.rm_f(virtual_object_csv_path)
  end

  scenario do
    ## Step 1: Register the constituents using the Register items bulk action
    click_button 'Register multiple items (via CSV)'
    expect(page).to have_css('h1', text: 'Register items')

    File.write(registration_csv_path, registration_csv)
    attach_file('Upload a CSV or Excel file', File.absolute_path(registration_csv_path))
    fill_in 'Describe this bulk action', with: "argo-b3 virtual object constituents #{run_id}"
    click_button 'Submit'

    # The row's Action column links to the bulk action; its Description column identifies this run.
    within('#bulk-actions-history-table tr', text: "argo-b3 virtual object constituents #{run_id}") do
      click_link 'Register items'
    end
    registered = registered_druids(source_ids: constituents.keys.map { |folder| source_id(folder) })
    constituents.each_key do |folder|
      druids[folder] = registered.fetch(source_id(folder))
      puts " *** argo-b3 virtual object constituent druid: #{druids[folder]} ***"
    end

    ## Step 2: Deposit the constituents
    deposit_multiple_items(description: "argo-b3 virtual object constituents #{run_id}",
                           mount_path: Settings.argo_b3_virtual_object_directory,
                           folders: constituents.keys.to_h { |folder| [druids[folder], { folder:, file_count: }] },
                           deposit_type: 'new item')

    ## Step 3: Register the virtual object
    virtual_object_druid = register_virtual_object
    puts " *** argo-b3 virtual object druid: #{virtual_object_druid} ***"

    ## Step 4: Deposit the virtual object, since a virtual object cannot have an open version
    deposit_without_files(druid: virtual_object_druid)

    ## Step 5: Create the virtual object using the Create virtual object bulk action
    create_virtual_object(virtual_object_druid:, constituent_druids: druids.values)

    ## Step 6: Verify the virtual object in Argo-B3
    expect_constituents_on_object_page(druid: virtual_object_druid, constituent_druids: druids.values)

    ## Step 7: Verify that the PURL page of each constituent links to the virtual object
    druids.each_value do |constituent_druid|
      expect_link_on_purl_page(druid: constituent_druid,
                               href: "#{Settings.purl_url}/#{bare_druid(virtual_object_druid)}",
                               text: virtual_object_title)
    end
  end

  def source_id(folder)
    "argo-b3-virtual-object:#{run_id}-#{folder}"
  end

  def registration_csv
    CSV.generate do |csv|
      csv << %w[content_type reading_order administrative_policy_object initial_workflow source_id title
                rights_view rights_download]
      constituents.each do |folder, title|
        csv << ['image', 'left-to-right', Settings.default_apo, 'registrationWF', source_id(folder), title,
                'world', 'world']
      end
    end
  end

  # @return [String] the druid of the registered virtual object
  def register_virtual_object
    visit start_url
    click_button 'Item', exact: true
    expect(page).to have_css('h1', text: 'Register an item')

    # Item details tab
    select 'image', from: 'Content type'
    choose 'Enter prefix to autogenerate source ID'
    fill_in 'Source ID prefix', with: 'integration'
    click_button 'Next'

    # Description tab
    fill_in 'Title', with: virtual_object_title
    click_button 'Next'

    # APO, collection, rights tab
    select_searchable_option_by_value(Settings.default_apo, from: 'APO')

    # Register tab
    find_by_id('deposit-tab').click
    click_button 'Register only'
    expect(page).to have_css('h1', text: virtual_object_title)
    page.current_url[/druid:[b-df-hjkmnp-tv-z]{2}[0-9]{3}[b-df-hjkmnp-tv-z]{2}[0-9]{4}/]
  end

  def create_virtual_object(virtual_object_druid:, constituent_druids:)
    # No header row: the virtual object druid, followed by the constituent druids in order.
    CSV.open(virtual_object_csv_path, 'w') { |csv| csv << [virtual_object_druid, *constituent_druids] }

    visit "#{start_url}/bulk_actions/create_virtual_object/new"
    attach_file('Upload a CSV or Excel file', File.absolute_path(virtual_object_csv_path))
    fill_in 'Describe this bulk action', with: bulk_action_description
    click_button 'Submit'

    within('#bulk-actions-history-table tr', text: bulk_action_description) do
      click_link 'Create virtual object'
    end
    # The page refreshes itself until complete; the counts are total / succeeded / failed.
    within('#bulk-action-status') { expect(page).to have_text('1 / 1 / 0', wait: Settings.timeouts.bulk_action) }
  end

  def expect_constituents_on_object_page(druid:, constituent_druids:)
    visit "#{start_url}/objects/#{druid}"
    # Creating the virtual object deposits a new version; status is from Solr, so may lag accessioning.
    reload_page_until_timeout! { page.has_css?('#overview-table tr', text: /Status\s+v2 Accessioned/, wait: 1) }

    # The constituents turbo-frame is lazily loaded when the tab is shown.
    find_by_id('constituents-tab').click
    within('#constituents-pane') do
      expect(page).to have_css('h2', text: "Items in this virtual object (#{constituent_druids.size})")
      constituent_druids.each do |constituent_druid|
        expect(page).to have_css('tbody tr', text: bare_druid(constituent_druid))
      end
    end
  end
end
