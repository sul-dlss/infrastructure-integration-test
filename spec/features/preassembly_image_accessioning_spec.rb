# frozen_string_literal: true

require 'druid-tools'

# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly_host at Settings.preassembly_bundle_directory
RSpec.describe 'Create and re-accession image object via Pre-assembly' do
  druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)

  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:preassembly_bundle_dir) { Settings.preassembly_bundle_directory }
  let(:remote_manifest_location) { "preassembly@#{Settings.preassembly_host}:#{preassembly_bundle_dir}" }
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-preassembly-image-#{random_noun}" }
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "image-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "image integration test #{label_random_words}" }
  let(:collection_name) { 'integration-testing' }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{druid},content
    CSV
  end

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  after do
    clear_downloads
  end

  scenario do
    # register new object
    select 'integration-testing', from: 'Admin Policy'
    select collection_name, from: 'Collection'
    select 'image', from: 'Content Type'
    fill_in 'Project Name', with: 'Integration Test - Image via Preassembly'

    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    druid = "druid:#{bare_object_druid}"
    puts " *** preassembly image accessioning druid: #{druid} ***" # useful for debugging

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    visit Settings.preassembly_url
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: preassembly_project_name
    select 'Pre Assembly Run', from: 'Job type'
    select 'Image', from: 'Content structure'
    fill_in 'Staging location', with: preassembly_bundle_dir

    click_button 'Submit'
    expect(page).to have_text 'Success! Your job is queued. ' \
                              'A link to job output will be emailed to you upon completion.'

    # go to job details page, download result
    first('td > a').click
    expect(page).to have_text preassembly_project_name

    # wait for preassembly background job to finish
    reload_page_until_timeout! do
      page.has_link?('Download', wait: 1)
    end

    click_link 'Download'
    wait_for_download
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'
    # delete the downloaded YAML file, so we don't pick it up by mistake during the re-accession
    delete_download(download)

    # ensure Image files are all there, per pre-assembly, organized into specified resources
    visit "#{Settings.argo_url}/view/#{druid}"

    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    files = all('tr.file')

    expect(files.size).to eq 2
    expect(files.first.text).to match(%r{image.jpg image/jpeg 28.\d KB})
    expect(files.last.text).to match(%r{image.jp2 image/jp2 137 KB})

    expect(find_table_cell_following(header_text: 'Content type').text).to eq('image') # filled in by accessioning

    sleep 10 # let's wait a bit before trying the re-accession to avoid a possible race condition

    ### Re-accession

    # Get the original version from the page
    elem = find_table_cell_following(header_text: 'Status')
    md = /^v(\d+) Accessioned/.match(elem.text)
    version = md[1].to_i

    visit Settings.preassembly_url

    expect(page).to have_text 'Complete the form below'

    fill_in 'Project name', with: random_project_name
    select 'Pre Assembly Run', from: 'Job type'
    fill_in 'Staging location', with: preassembly_bundle_dir
    select 'Filename', from: 'Content metadata creation'

    click_button 'Submit'

    expect(page).to have_text 'Success! Your job is queued. ' \
                              'A link to job output will be emailed to you upon completion.'

    first('td > a').click # Click to the job details page

    reload_page_until_timeout! do
      page.has_link?('Download', wait: 1)
    end

    click_link 'Download'

    wait_for_download

    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    prefixed_druid = yaml[:pid]
    latest_version = version + 1

    visit "#{Settings.argo_url}/view/#{prefixed_druid}"
    reload_page_until_timeout! do
      click_button 'Events' # expand the Events section

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
    iiif_manifest_url = find(:xpath, '//link[@rel="alternate" and @title="IIIF Manifest"]', visible: false)[:href]
    iiif_manifest = JSON.parse(Faraday.get(iiif_manifest_url).body)
    canvas_url = iiif_manifest.dig('sequences', 0, 'canvases', 0, '@id')
    canvas = JSON.parse(Faraday.get(canvas_url).body)
    image_url = canvas.dig('images', 0, 'resource', '@id')
    image_response = Faraday.get(image_url)
    expect(image_response.status).to eq(200)
    expect(image_response.headers['content-type']).to include('image/jpeg')

    # The below confirms that preservation replication is working: we only replicate a
    # Moab version once it's been written successfully to on prem storage roots, and
    # we only log an event to dor-services-app after a version has successfully replicated
    # to a cloud endpoint.  So, confirming that both versions of our test object have
    # replication events logged for all three cloud endpoints is a good basic test of the
    # entire preservation flow.
    visit "#{Settings.argo_url}/view/#{prefixed_druid}"
    druid_tree_str = DruidTools::Druid.new(prefixed_druid).tree.join('/')

    latest_s3_key = "#{druid_tree_str}.v000#{latest_version}.zip"
    reload_page_until_timeout! do
      click_button 'Events' # expand the Events section

      # this is a hack that forces the event section to scroll into view; the section
      # is lazily loaded, and won't actually be requested otherwise, even if the button
      # is clicked to expand the event section.
      page.execute_script 'window.scrollBy(0,100);'

      # events are loaded lazily, give the network a few moments
      page.has_text?(latest_s3_key, wait: 3)
    end

    # the event log should eventually contain an event for replication of each version that
    # this test created to every endpoint we archive to
    poll_for_matching_events!(prefixed_druid) do |events|
      (1..latest_version).all? do |cur_version|
        cur_s3_key = "#{druid_tree_str}.v000#{cur_version}.zip"

        %w[aws_s3_west_2 ibm_us_south aws_s3_east_1].all? do |endpoint_name|
          events.any? do |event|
            event[:event_type] == 'druid_version_replicated' &&
              event[:data]['parts_info'] &&
              event[:data]['parts_info'].size == 1 && # we only expect one part for this small object
              event[:data]['parts_info'].first['s3_key'] == cur_s3_key &&
              event[:data]['endpoint_name'] == endpoint_name
          end
        end
      end
    end
  end
end
