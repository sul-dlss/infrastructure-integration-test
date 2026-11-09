# frozen_string_literal: true

# Integration: Argo-B3, DSA, Purl, Stacks, Preservation
# The files are in folders on a mount that argo-b3 can read (Settings.argo_b3_multi_item_deposit_directory).
# Each v2 folder drops one file from its v1 folder and adds another, so that redepositing deletes and adds a file.
RSpec.describe 'Use Argo-B3 to register, deposit, and redeposit multiple items', type: :accessioning do
  let(:start_url) { Settings.argo_b3_url }
  let(:run_id) { SecureRandom.uuid }
  let(:registration_csv_path) { 'tmp/argo_b3_multi_item_registration.csv' }
  let(:items) do
    {
      'image' => { content_type: 'image', reading_order: 'left-to-right',
                   title: "argo-b3 multi-item image #{random_phrase}",
                   files: { 'v1' => %w[argo-logo.png image.jpg sul-logo.png],
                            'v2' => %w[argo-logo.png image.jpg vision_for_stanford.jpg] } },
      # Hierarchical filepaths, which are allowed only for some content types (e.g., file).
      'file' => { content_type: 'file', reading_order: nil,
                  title: "argo-b3 multi-item file #{random_phrase}",
                  files: { 'v1' => %w[README.md config/settings.yml images/image.jpg],
                           'v2' => %w[README.md config/settings.yml config/settings/qa.yml] } }
    }
  end
  # Populated by registration, keyed like items.
  let(:druids) { {} }

  before do
    authenticate!(start_url:, expected_text: 'Argo dashboard')
  end

  after do
    FileUtils.rm_f(registration_csv_path)
  end

  scenario do
    ## Step 1: Register the items, with different content types, using the Register items bulk action
    click_button 'Register multiple items (via CSV)'
    expect(page).to have_css('h1', text: 'Register items')

    File.write(registration_csv_path, registration_csv)
    attach_file('Upload a CSV or Excel file', File.absolute_path(registration_csv_path))
    fill_in 'Describe this bulk action', with: "argo-b3 multi-item deposit #{run_id}"
    click_button 'Submit'

    click_link "argo-b3 multi-item deposit #{run_id}"
    registered = registered_druids(source_ids: items.keys.map { |key| source_id(key) })
    items.each_key do |key|
      druids[key] = registered.fetch(source_id(key))
      puts " *** argo-b3 multi-item deposit #{key} druid: #{druids[key]} ***"
    end

    ## Step 2: Deposit the items
    deposit_items(version: 'v1')

    ## Step 3: Verify the deposited items
    items.each do |key, item|
      expect_files_on_object_page(druid: druids[key], filenames: item[:files]['v1'])
      published_filenames = published_cocina_filenames(druid: druids[key], version: 1)
      expect(published_filenames).to include(*item[:files]['v1'])
    end
    expect_accessible_iiif_image(druid: druids['image'], title: items['image'][:title])

    ## Step 4: Redeposit the items, deleting one file and adding another
    deposit_items(version: 'v2', version_description: "argo-b3 multi-item redeposit #{run_id}")

    ## Step 5: Verify the redeposited items
    items.each do |key, item|
      deleted_filenames = item[:files]['v1'] - item[:files]['v2']
      expect_files_on_object_page(druid: druids[key], filenames: item[:files]['v2'], absent_filenames: deleted_filenames)
      published_filenames = published_cocina_filenames(druid: druids[key], version: 2)
      expect(published_filenames).to include(*item[:files]['v2'])
      expect(published_filenames).not_to include(*deleted_filenames)

      expect_replication_event_on_object_page(druid: druids[key], version: 2)
      confirm_archive_zip_replication_events!(druid: druids[key], to_version: 2)
      retrieve_and_fixity_check_replicated_druid!(druid: druids[key], expected_version: 2)
    end
  end

  def source_id(key)
    "argo-b3-multi-item-deposit:#{run_id}-#{key}"
  end

  def registration_csv
    CSV.generate do |csv|
      csv << %w[content_type reading_order administrative_policy_object initial_workflow source_id title
                rights_view rights_download]
      items.each do |key, item|
        csv << [item[:content_type], item[:reading_order], Settings.default_apo, 'registrationWF', source_id(key),
                item[:title], 'world', 'world']
      end
    end
  end

  # @param version [String] v1 or v2, which selects the folders and whether the items are new or redeposited
  def deposit_items(version:, version_description: nil)
    deposit_multiple_items(description: "argo-b3 multi-item deposit #{run_id} #{version}",
                           mount_path: Settings.argo_b3_multi_item_deposit_directory,
                           folders: items.to_h do |key, item|
                             [druids[key], { folder: "#{key}-#{version}", file_count: item[:files][version].size }]
                           end,
                           deposit_type: version == 'v1' ? 'new item' : 'redeposit',
                           version_description:)
  end

  # Replication follows accessioning, so reloads until the event is shown.
  def expect_replication_event_on_object_page(druid:, version:)
    visit "#{start_url}/objects/#{druid}"
    reload_page_until_timeout! do
      # The events turbo-frame is lazily loaded when the tab is shown.
      find_by_id('events-tab').click
      within('#events-pane') do
        page.has_css?('#events-table tr', text: /Druid version replicated\s+#{version}\b/, wait: 5)
      end
    end
  end
end
