# frozen_string_literal: true

require 'druid-tools'

# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
RSpec.describe 'Create and re-accession image object via Pre-assembly' do
  bare_druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:preassembly_bundle_dir) { Settings.preassembly.bundle_directory }
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:local_file_manifest_location) { 'tmp/file_manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-preassembly-image-#{random_noun}-#{random_alpha}" }
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "image-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "image integration test #{label_random_words}" }
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
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
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
    select 'integration-testing', from: 'Admin Policy'
    select collection_name, from: 'Collection'
    select 'image', from: 'Content Type'

    sleep 1 # if you notice the project name not filling in completely, try this to
    #           give the page a moment to load so we fill in the full text field
    fill_in 'Project Name', with: 'Integration Test - Image via Preassembly'
    fill_in 'Source ID', with: "#{source_id}-#{random_alpha}"
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_druid = find('table a').text
    druid = "druid:#{bare_druid}"
    puts " *** preassembly image accessioning druid: #{druid} ***" # useful for debugging

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

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
    # delete the downloaded YAML file, so we don't pick it up by mistake during the re-accession
    delete_download(download)

    # ensure files are all there, per pre-assembly, organized into specified resources
    visit "#{Settings.argo_url}/view/#{druid}"

    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    files = all('tr.file')

    expect(files.size).to eq 6
    expect(files[0].text).to match(%r{argo-logo.png image/png 10.\d KB})
    expect(files[1].text).to match(%r{argo-logo.jp2 image/jp2 10\.*\d* KB})
    expect(files[2].text).to match(%r{image.jpg image/jpeg 28.\d KB})
    expect(files[3].text).to match(%r{image.jp2 image/jp2 137 KB})
    expect(files[4].text).to match(%r{sul-logo.png image/png 19.\d KB})
    expect(files[5].text).to match(%r{sul-logo.jp2 image/jp2 30.\d KB})

    expect(find_table_cell_following(header_text: 'Content type').text).to eq('image') # filled in by accessioning

    # check technical metadata for all non-thumbnail files
    reload_page_until_timeout! do
      click_link_or_button 'Technical metadata' # expand the Technical metadata section

      # this is a hack that forces the event section to scroll into view; the section
      # is lazily loaded, and won't actually be requested otherwise, even if the button
      # is clicked to expand the event section.
      page.execute_script 'window.scrollBy(0,100);'

      # events are loaded lazily, give the network a few moments
      page.has_text?('v1 Accessioned', wait: 2)
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

    # Get the original version from the page
    elem = find_table_cell_following(header_text: 'Status')
    md = /^v(\d+) Accessioned/.match(elem.text)
    version = md[1].to_i

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

    first('td > a').click # Click to the job details page

    reload_page_until_timeout! do
      page.has_link?('Download', wait: 1)
    end

    click_link_or_button 'Download'

    wait_for_download

    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    prefixed_druid = yaml[:pid]
    latest_version = version + 1

    visit "#{Settings.argo_url}/view/#{prefixed_druid}"

    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: "v#{latest_version} Accessioned")

    # ensure changed files are all there, per pre-assembly
    files = all('tr.file')
    expect(files.size).to eq 6
    expect(files[0].text).to match(%r{argo-logo.png image/png 97.\d KB})
    expect(files[1].text).to match(%r{argo-logo.jp2 image/jp2 140 KB})
    expect(files[2].text).to match(%r{image.jpg image/jpeg 28.\d KB})
    expect(files[3].text).to match(%r{image.jp2 image/jp2 137 KB})
    expect(files[4].text).to match(%r{vision_for_stanford.jpg image/jpeg 8.\d+ KB})
    expect(files[5].text).to match(%r{vision_for_stanford.jp2 image/jp2 26.\d KB})

    # check technical metadata for all non-thumbnail files
    reload_page_until_timeout! do
      click_link_or_button 'Technical metadata' # expand the Technical metadata section

      # this is a hack that forces the event section to scroll into view; the section
      # is lazily loaded, and won't actually be requested otherwise, even if the button
      # is clicked to expand the event section.
      page.execute_script 'window.scrollBy(0,100);'

      # events are loaded lazily, give the network a few moments
      page.has_text?("v#{latest_version} Accessioned", wait: 2)
    end
    page.has_text?('filetype', count: 3)
    page.has_text?('file_modification', count: 3)
    page.has_text?('bytes 9071') # vision_for_stanford.jpg (new file)
    page.has_text?('bytes 29634') # file from original accession, neither removed nor changed.

    reload_page_until_timeout! do
      click_link_or_button 'Events' # expand the Events section

      # this is a hack that forces the event section to scroll into view; the section
      # is lazily loaded, and won't actually be requested otherwise, even if the button
      # is clicked to expand the event section.
      page.execute_script 'window.scrollBy(0,100);'

      # events are loaded lazily, give the network a few moments
      page.has_text?("v#{latest_version} Accessioned", wait: 3)
    end

    # This section confirms the object has been published to PURL and has a
    # valid IIIF manifest
    # wait for the PURL name to be published by checking for collection name
    expect_text_on_purl_page(druid:, text: collection_name)
    expect_text_on_purl_page(druid:, text: object_label)
    iiif_manifest_url = find(:xpath, '//link[@rel="alternate" and @title="IIIF Manifest"]', visible: false)[:href]
    iiif_manifest = JSON.parse(Faraday.get(iiif_manifest_url).body)
    canvas_url = iiif_manifest.dig('sequences', 0, 'canvases', 0, '@id')
    canvas = JSON.parse(Faraday.get(canvas_url).body)
    image_url = canvas.dig('images', 0, 'resource', '@id')
    image_response = Faraday.get(image_url)
    expect(image_response.status).to eq(200)
    expect(image_response.headers['content-type']).to include('image/jpeg')

    visit_argo_and_confirm_event_display!(druid:, version: latest_version)
    confirm_archive_zip_replication_events!(druid:, from_version: 1, to_version: latest_version)
  end
end
