# frozen_string_literal: true

# Use pre-assembly to accession a raster based GIS object
# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.gis.robots_content_root
# NOTE: this spec will be skipped unless run on staging, since there is no geoserver-qa
RSpec.describe 'Create gis object via Pre-assembly', if: $sdr_env == 'stage' do
  bare_druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:project_name) { 'Integration Test - GIS via preassembly' }
  let(:preassembly_bundle_dir) { Settings.preassembly.gis_bundle_directory } # where we will stage the content
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:preassembly_project_name) { "IntegrationTest-preassembly-gis-#{random_noun}-#{random_alpha}" }
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "geo-preassembly-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "gis preassembly raster integration test #{label_random_words}" }
  let(:collection_name) { 'Integration Test Collection - GIS' }
  let(:apo_name) { 'APO for GIS' }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{bare_druid},content
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
      #{preassembly_bundle_dir}/content && rm -fr #{preassembly_bundle_dir}/manifest.csv`
    end
  end

  scenario do
    select apo_name, from: 'Admin Policy'
    select collection_name, from: 'Collection'
    select 'geo', from: 'Content Type'
    fill_in 'Project Name', with: project_name
    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_druid = find('table a').text
    druid = "druid:#{bare_druid}"
    puts " *** preassembly gis accessioning druid: #{druid} ***" # useful for debugging

    # Move gis test data to preassembly bundle directory
    # Should this test data be deleted from the server,
    # a zipped copy is available at spec/fixtures/gis_integration_test_data_raster.zip
    test_data_source_folder = File.join(Settings.gis.robots_content_root, 'integration_test_data_raster')
    test_data_destination_folder = File.join(Settings.preassembly.gis_bundle_directory, 'content')
    copy_command = "ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} " \
                   "\"mkdir -p #{test_data_destination_folder} " \
                   "&& cp #{test_data_source_folder}/* #{test_data_destination_folder}\""
    `#{copy_command}`
    unless $CHILD_STATUS.success?
      raise("unable to copy #{test_data_source_folder} to #{test_data_destination_folder} - got #{$CHILD_STATUS.inspect}")
    end

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    manifest_copy_command = "scp #{local_manifest_location} #{remote_manifest_location}"
    `#{manifest_copy_command}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    visit Settings.preassembly.url
    expect(page).to have_css('h1', text: 'Complete the form below')

    # sleep 1 # if you notice the project name not filling in completely, try this to
    #           give the page a moment to load so we fill in the full text field
    fill_in 'Project name', with: preassembly_project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Geo', from: 'Content type'
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
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    # ensure files are all there, per pre-assembly, organized into specified resources
    visit "#{Settings.argo_url}/view/#{druid}"

    # verify the gisAssemblyWF workflow completes
    reload_page_until_timeout! do
      page.has_selector?('#workflow-details-status-gisAssemblyWF', text: 'completed', wait: 1)
    end
    # verify the gisDeliveryWF workflow completes
    reload_page_until_timeout! do
      page.has_selector?('#workflow-details-status-gisDeliveryWF', text: 'completed', wait: 1)
    end
    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    # look for expected files produced by GIS workflows
    files = all('tr.file')
    expect(files.size).to eq 7
    expect(files[0].text).to match(%r{SC_Color_WGS.tif image/tiff 9.\d\d MB})
    expect(files[1].text).to match(%r{SC_Color_WGS.tfw text/plain 8\d Bytes})
    expect(files[2].text).to match(%r{SC_Color_WGS.tif.ovr application/octet-stream 4.\d\d MB})
    expect(files[3].text).to match(%r{preview.jpg image/jpeg 6.\d\d KB})
    expect(files[4].text).to match(%r{SC_Color_WGS.tif.xml application/xml 2\d.\d KB})
    expect(files[5].text).to match(%r{SC_Color_WGS-iso19139.xml application/xml 2\d.\d KB})
    expect(files[6].text).to match(%r{SC_Color_WGS-fgdc.xml application/xml 5.\d\d KB})

    # verify that the content type is "geo"
    expect(find_table_cell_following(header_text: 'Content type').text).to eq('geo')

    # Confirms that the object has been published to PURL.
    # Confirming here because there may be a file system latency for the purl xml file.
    # If the purl xml file is not available, release won't work.
    # This may be obviated when no longer using the file system for purl xml files.
    expect_text_on_purl_page(druid:, text: collection_name)

    # release to Earthworks
    visit "#{Settings.argo_url}/view/#{druid}"
    click_link_or_button 'Manage release'
    select 'Earthworks', from: 'to'
    click_link_or_button('Submit')
    expect(page).to have_text('Release object job was successfully created.')

    # This section confirms the object has been published to PURL
    # wait for the PURL name to be published by checking for collection name and check for bits of expected metadata
    expect_text_on_purl_page(druid:, text: collection_name)
    expect_link_on_purl_page(druid:,
                             text: 'View in EarthWorks',
                             href: "#{Settings.earthworks_url}/stanford-#{bare_druid}")
    expect(page).to have_no_text(object_label) # the original object label has been replaced
    expect(page).to have_text('Proposed Southern Crossings of San Francisco Bay (Raster Image)') # with the new object label
    expect(page).to have_text('This raster dataset is a georeferenced image') # abstract
    expect(page).to have_text('cartographic') # type of resource
    expect(page).to have_text('GeoTIFF') # form
    expect(page).to have_text('Scale not given ; EPSG::4326') # map data
    expect(page).to have_text('Geospatial data') # genre
    expect(page).to have_text('Cartographic dataset') # genre

    # click Earthworks link and verify it was released
    click_link_or_button 'View in EarthWorks'
    reload_page_until_timeout!(text: 'Proposed Southern Crossings of San Francisco Bay (Raster Image)')
  end
end
