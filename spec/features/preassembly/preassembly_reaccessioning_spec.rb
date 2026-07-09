# frozen_string_literal: true

require 'druid-tools'

# Integration: Argo, DSA, Preassembly, Purl
# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
RSpec.describe 'Create and re-accession image object via Pre-assembly', type: :preassembly do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:bare_druid) { druid.delete_prefix('druid:') }
  let(:druid) { test_data[:druid] }
  let(:object_label) { test_data[:title] }
  let(:test_data) { load_test_data(spec_name: 'preassembly_accessioning') }
  let(:preassembly_bundle_dir) { Settings.preassembly.bundle_directory }
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:local_file_manifest_location) { 'tmp/file_manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-preassembly-reaccessioning-#{SecureRandom.uuid}" }
  let(:collection_name) { 'integration-testing' }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{bare_druid},content
    CSV
  end
  let(:preassembly_reaccession_manifest_csv) do
    <<~CSV
      druid,object
      #{bare_druid},#{bare_druid}
    CSV
  end

  before do
    authenticate!(start_url:, expected_text: object_label)

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end
  end

  after do
    clear_downloads
    FileUtils.rm_rf(bare_druid)
    unless bare_druid.empty?
      `ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} rm -rf \
      #{preassembly_bundle_dir}/#{bare_druid}`
    end
  end

  scenario do
    expect(page).to have_text(/v\d+ Accessioned/)

    # Get the original version from the page
    elem = find_table_cell_following(header_text: 'Status')
    md = /^v(\d+) Accessioned/.match(elem.text)
    version = md[1].to_i

    if version > 1
      raise <<~MESSAGE
        This object is already above version 1, meaning it has already been re-accessioned by this spec before.
        The spec assumes a freshly-accessioned object and is not safe to replay against an already-reaccessioned druid.

        To get a fresh object if you want to run this spec again, remove the data and re-run the specs to create a new object:

        ```
        rm tmp/*_data.yml
        bin/rspec spec/features/registration
        bin/rspec spec/features/accessioning/preassembly_accessioning_spec.rb
        bin/rspec spec/features/preassembly/preassembly_reaccessioning_spec.rb
        ```

         or just redo the full suite: `bin/rspec`.
      MESSAGE
    end

    files = all('tr.file')

    expect(files.size).to eq 6
    expect(files[0].text).to match(%r{argo-logo.png image/png \d+.\d KB})
    expect(files[1].text).to match(%r{argo-logo.jp2 image/jp2 \d+\.*\d* KB})
    expect(files[2].text).to match(%r{image.jpg image/jpeg \d+.\d KB})
    expect(files[3].text).to match(%r{image.jp2 image/jp2 \d+\.*\d* KB})
    expect(files[4].text).to match(%r{sul-logo.png image/png \d+.\d+ KB})
    expect(files[5].text).to match(%r{sul-logo.jp2 image/jp2 \d+.\d+ KB})

    expect(find_table_cell_following(header_text: 'Content type').text).to eq('image') # filled in by accessioning

    # check technical metadata for all non-thumbnail files
    reload_page_until_timeout! do
      click_link_or_button 'Technical metadata' # expand the Technical metadata section

      # Scroll to the bottom so the lazily-loaded section enters the viewport
      # and the browser fetches its content.
      page.scroll_to(:bottom)

      # events are loaded lazily, give the network a few moments
      page.has_text?("v#{version} Accessioned", wait: 2)
    end
    page.has_text?('filetype', count: 3)
    page.has_text?('file_modification', count: 3)
    page.has_text?('bytes 29634') # file to be missing from manifest for targeted re-accession

    # Download CSV from Argo
    click_link_or_button 'Download CSV'
    wait_for_download
    items = CSV.read(download)
    # delete row for the deleted image file from the CSV and for the changed image file's jp2
    items.reject! { |row| row[1] == 'Image 3' || row[4] == 'argo-logo.jp2' }
    # add a row for a new image file
    items << [bare_druid, 'Image 4', 'image', '3', 'vision_for_stanford.jpg', 'vision_for_stanford.jpg', 'no', 'no', 'yes',
              'world', 'world', '', 'image/jpeg', '']
    CSV.open(local_file_manifest_location, 'w') do |csv|
      items.each do |item|
        csv << item
      end
    end

    delete_download(download)

    # scp file manifest to preassembly
    `scp #{local_file_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_file_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    # scp manifest for reaccession to preassembly
    File.write(local_manifest_location, preassembly_reaccession_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    # Create local dir for scp:
    Dir.mkdir(bare_druid)
    # Replace one of the files with a different file
    FileUtils.cp('spec/fixtures/argo-home.png', "#{bare_druid}/argo-logo.png")
    # Add a new file
    FileUtils.cp('spec/fixtures/vision_for_stanford.jpg', bare_druid)

    # scp druid directory to preassembly
    `scp -r #{bare_druid} #{remote_manifest_location}`
    unless $CHILD_STATUS.success? # rubocop:disable Style/IfUnlessModifier
      raise("unable to scp #{bare_druid} #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    sleep 20 # let's wait a bit before trying the re-accession to avoid a possible race condition

    ### Re-accession

    visit Settings.preassembly.url

    expect(page).to have_text 'Start new job'

    sleep 1 # if you notice the project name not filling in completely, try this
    fill_in 'Project name', with: random_project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Image', from: 'Content type'
    fill_in 'Staging location', with: preassembly_bundle_dir
    select 'Group by filename', from: 'Processing configuration' unless Settings.ocr.enabled
    choose 'batch_context_using_file_manifest_true'

    click_link_or_button 'Submit'

    expect(page).to have_text 'Success! Your job is queued. ' \
                              'A link to job output will be emailed to you upon completion.'

    # Get the preassembly job number
    cell = first('td', text: /^Job #\d+/)
    job_id = cell.text.match(/^Job #(\d+)/)[1]

    save_test_data(spec_name: 'preassembly_reaccessioning', data: { 'job_id' => job_id.to_i })

    visit "#{Settings.preassembly.url}/job_runs/#{job_id}"

    reload_page_until_timeout! do
      page.has_link?('Download', wait: 1)
    end

    click_link_or_button 'Download'

    wait_for_download

    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'
    # delete the downloaded YAML file, so we don't pick it up by mistake during the re-accession
    delete_download(download)

    prefixed_druid = yaml[:pid]
    latest_version = version + 1

    visit "#{Settings.argo_url}/view/#{prefixed_druid}"

    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: "v#{latest_version} Accessioned")

    # ensure changed files are all there, per pre-assembly
    files = all('tr.file')
    expect(files.size).to eq 6
    expect(files[0].text).to match(%r{argo-logo.png image/png \d+.\d KB})
    expect(files[1].text).to match(%r{argo-logo.jp2 image/jp2 \d+\.*\d* KB})
    expect(files[2].text).to match(%r{image.jpg image/jpeg \d+.\d KB})
    expect(files[3].text).to match(%r{image.jp2 image/jp2 \d+\.*\d* KB})
    expect(files[4].text).to match(%r{vision_for_stanford.jpg image/jpeg \d+.\d+ KB})
    expect(files[5].text).to match(%r{vision_for_stanford.jp2 image/jp2 \d+.\d+ KB})

    # check technical metadata for all non-thumbnail files
    reload_page_until_timeout! do
      click_link_or_button 'Technical metadata' # expand the Technical metadata section

      # Scroll to the bottom so the lazily-loaded section enters the viewport
      # and the browser fetches its content.
      page.scroll_to(:bottom)

      # events are loaded lazily, give the network a few moments
      page.has_text?("v#{latest_version} Accessioned", wait: 2)
    end
    page.has_text?('filetype', count: 3)
    page.has_text?('file_modification', count: 3)
    page.has_text?('bytes 9071') # vision_for_stanford.jpg (new file)
    page.has_text?('bytes 29634') # file from original accession, neither removed nor changed.
  end
end
