# frozen_string_literal: true

require 'druid-tools'

# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly_host at Settings.preassembly_bundle_directory
RSpec.describe 'Create and re-accession object via Pre-assembly', type: :feature do
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
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{druid},content
    CSV
  end

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Register DOR Items')
  end

  after do
    clear_downloads
  end

  scenario do
    # register new object
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    select 'Image', from: 'Content Type'
    fill_in 'Project Name', with: 'Integration Test - Image via Preassembly'
    click_button 'Add another row'
    td_list = all('td.invalidDisplay')
    td_list[0].click
    fill_in '1_source_id', with: source_id
    td_list[1].click
    fill_in '1_label', with: object_label
    find_field('1_label').send_keys :enter
    click_button('Register')
    # wait for object to be registered
    find('td[aria-describedby=data_status][title=success]')
    druid = find('td[aria-describedby=data_druid]').text
    # puts druid # useful for debugging

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
    fill_in 'Bundle dir', with: preassembly_bundle_dir

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, download result
    first('td > a').click
    expect(page).to have_content preassembly_project_name

    # wait for preassembly background job to finish
    reload_page_until_timeout!(text: 'Download', as_link: true)

    click_link 'Download'
    wait_for_download
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    # ensure Image files are all there, per pre-assembly, organized into specified resources
    visit "#{Settings.argo_url}/view/#{druid}"

    reload_page_until_timeout!(text: "Resource (1)\nimage\nLabel\nImage 1")
    files = all('tr.file')

    expect(files.size).to eq 2
    expect(files.first.text).to match(%r{image.jpg image/jpeg 28.\d KB})
    expect(files.last.text).to match(%r{image.jp2 image/jp2 64.\d KB})

    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    expect(find_table_cell_following(header_text: 'Content type').text).to eq('image') # filled in by accessioning

    sleep 10 # let's wait a bit before trying the re-accession to avoid a possible race condition

    ### Re-accession

    # Get the original version from the page
    elem = find_table_cell_following(header_text: 'Status')
    md = /^v(\d+) Accessioned/.match(elem.text)
    version = md[1].to_i

    visit Settings.preassembly_url

    expect(page).to have_content 'Complete the form below'

    fill_in 'Project name', with: random_noun
    select 'Pre Assembly Run', from: 'Job type'
    fill_in 'Bundle dir', with: preassembly_bundle_dir
    select 'Filename', from: 'Content metadata creation'

    click_button 'Submit'

    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    first('td > a').click # Click to the job details page

    reload_page_until_timeout!(text: 'Download', as_link: true)

    click_link 'Download'

    wait_for_download

    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    prefixed_druid = "druid:#{yaml[:pid]}"
    latest_version = version + 1

    visit "#{Settings.argo_url}/view/#{prefixed_druid}"
    reload_page_until_timeout!(text: "v#{latest_version} Accessioned", with_reindex: true)

    # This section confirms the object has been published to PURL and has a
    # valid IIIF manifest
    visit "#{Settings.purl_url}/#{druid.delete_prefix('druid:')}"
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
    reload_page_until_timeout!(text: latest_s3_key, with_events_expanded: true)

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
