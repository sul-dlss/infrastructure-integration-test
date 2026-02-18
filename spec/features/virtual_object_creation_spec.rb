# frozen_string_literal: true

# Integration: Argo, DSA, Preassembly, Purl
RSpec.describe 'Use Argo to create a virtual object with constituent objects' do
  # Can be run with more than the default 2 constituents:
  # SETTINGS__NUMBER_OF_CONSTITUENTS=4 bundle exec rspec spec/features/virtual_object_creation_spec.rb
  bare_druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)
  let(:start_url) { Settings.argo_url }
  let(:num_constituents) { Settings.number_of_constituents }
  let(:project_name) { 'Integration Test - Virtual object via Preassembly' }
  let(:preassembly_bundle_dir) { Settings.preassembly.virtual_object_bundle_directory } # where we will stage the content
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:preassembly_project_name) { "IntegrationTest-virtual-object-preassembly-#{random_noun}-#{random_alpha}" }
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "virtual-object-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "virtual object integration test #{label_random_words}" }
  let(:collection_name) { 'integration-testing' }
  let(:apo_name) { 'integration-testing' }
  let(:csv_path) { File.join(DownloadHelpers::PATH, 'virtual-object.csv') }
  let(:virtual_objects_description) { random_phrase }
  let(:constituent_druids) { [] }

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  after do
    clear_downloads
    if constituent_druids.any?
      constituent_druids.each do |druid|
        `ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} rm -rf \
        #{preassembly_bundle_dir}/#{druid} && rm -rf #{preassembly_bundle_dir}/manifest.csv`
      end
    end
  end

  scenario do
    # Register constituent objects
    num_constituents.times do |i|
      visit "#{Settings.argo_url}/registration"
      select apo_name, from: 'Admin Policy'
      select collection_name, from: 'Collection'
      select 'image', from: 'Content Type'
      fill_in 'Project Name', with: project_name
      fill_in 'Source ID', with: "#{source_id}-#{i}"
      fill_in 'Label', with: "#{object_label} #{i}"
      click_button 'Register'

      # wait for object to be registered
      expect(page).to have_text 'Items successfully registered.'

      bare_druid = find('table a').text
      druid = "druid:#{bare_druid}"
      puts " *** preassembly virtual object constituent druid: #{druid} ***" # useful for debugging
      constituent_druids << druid.delete_prefix('druid:')
    end

    # create manifest.csv file and scp it to preassembly staging directory
    rows = num_constituents.times.map do |i|
      "#{constituent_druids[i]},#{constituent_druids[i]}"
    end
    preassembly_manifest_csv =
      <<~CSV
        druid,object
        #{rows.join("\n")}
      CSV

    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    # Stage the content on preassembly server, using the same image file in each directory
    constituent_druids.each do |druid|
      copy_command = "ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} " \
                     "\"mkdir -p #{preassembly_bundle_dir}/#{druid} " \
                     "&& cp #{preassembly_bundle_dir}/object_files/* #{preassembly_bundle_dir}/#{druid}/\""
      `#{copy_command}`
    end
    # start a preassembly job to stage the content
    visit Settings.preassembly.url
    expect(page).to have_css('h1', text: 'Start new job')

    sleep 1 # if you notice the project name not filling in completely, try this
    fill_in 'Project name', with: preassembly_project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Image', from: 'Content type'
    fill_in 'Staging location', with: preassembly_bundle_dir

    click_link_or_button 'Submit'
    expect(page).to have_text 'Success! Your job is queued. ' \
                              'A link to job output will be emailed to you upon completion.'

    # go to job details page, download result
    first('td > a').click
    expect(page).to have_text preassembly_project_name

    # wait for preassembly background job to finish
    reload_page_until_timeout! do
      page.has_link?('Download', wait: 1)
    end

    click_link_or_button 'Download'
    wait_for_download
    puts "Download is #{download}: #{File.read(download)}"
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'
    # delete the downloaded YAML file, so we don't pick it up by mistake later
    delete_download(download)

    # Create virtual object
    virtual_object_label = random_phrase
    virtual_object_druid = deposit_object(label: virtual_object_label, viewing_direction: 'left-to-right')
    puts " *** virtual object druid: #{virtual_object_druid} ***" # useful for debugging

    # Create CSV: virtual_object_druid, constituent_druid, constituent_druid
    virtual_object_row = [virtual_object_druid, constituent_druids].flatten
    CSV.open(csv_path, 'w') do |csv|
      csv << virtual_object_row
    end

    # Use Bulk Actions to upload CSV
    visit start_url
    click_link_or_button "Bulk\u00a0Action"
    expect(page).to have_text 'Bulk Actions'
    click_link_or_button 'New Bulk Action'
    expect(page).to have_text 'New Bulk Action'
    select 'Create virtual object', from: 'action_type'
    expect(page).to have_text 'Create one or more virtual objects'
    find('input#csv_file').attach_file(csv_path)
    find('textarea#description').fill_in(with: virtual_objects_description)
    click_link_or_button 'Submit'

    expect(page).to have_text 'Create virtual objects job was successfully created.'

    Timeout.timeout(Settings.timeouts.bulk_action) do
      loop do
        page.driver.browser.navigate.refresh

        relevant_bulk_action = find(:xpath, "//tr[td = '#{virtual_objects_description}']")
        within(relevant_bulk_action) do
          status_text = all('td')[3].text
          next unless status_text == 'Completed'

          results_text = all('td')[4].text
          expect(results_text).to eq('1 / 1 / 0')
        end

        break
      end
    end

    visit "#{start_url}/view/#{virtual_object_druid}"
    reload_page_until_timeout!(text: 'v2 Accessioned')

    # Confirm constituent druids are listed in Content
    constituents_with_prefix = constituent_druids.map { |druid| "druid:#{druid}" }
    resources_text = all('.external-file a').map(&:text)

    expect(resources_text).to match_array(constituents_with_prefix)

    # Verify that the purl page of each constituent druid points at the "parent" virtual object purl
    constituent_druids.each do |constituent_druid|
      expect_link_on_purl_page(
        druid: constituent_druid,
        href: "#{Settings.purl_url}/#{virtual_object_druid.delete_prefix('druid:')}",
        text: virtual_object_label
      )
    end
  end
end
