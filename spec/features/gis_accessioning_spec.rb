# frozen_string_literal: true

require 'druid-tools'

# Accession a vector based GIS object
# NOTE: this spec will be skipped unless run on staging, since there is no geoserver-qa
RSpec.describe 'Create and accession GIS item object', if: $sdr_env == 'stage' do
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:project_name) { 'Integration Test - GIS' }
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "gis-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "gis integration test #{label_random_words}" }
  let(:collection_name) { 'Integration Test Collection - GIS' }
  # this APO must exist on argo-stage and argo-qa and have "Integration Test Collection - GIS" collection available
  let(:apo_name) { 'APO for GIS' }

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  scenario do
    # register new GIS object
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
    puts " *** GIS accessioning druid: #{bare_druid} ***" # useful for debugging
    druid = "druid:#{bare_druid}"

    # Go to kurma server and copy test content to the druid folder so it can be accessioned
    # Should this test data be deleted from the server,
    # a zipped copy is available at spec/fixtures/gis_integration_test_data_vector.zip
    test_data_source_folder = File.join(Settings.gis.robots_content_root, 'integration_test_data_vector')
    test_data_destination_folder = File.join(DruidTools::Druid.new(druid, Settings.gis.robots_content_root).path, 'content')
    copy_command = "ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} " \
                   "\"mkdir -p #{test_data_destination_folder} " \
                   "&& cp #{test_data_source_folder}/* #{test_data_destination_folder}\""
    `#{copy_command}`

    # visit argo detail page
    visit "#{Settings.argo_url}/view/#{druid}"

    # add gisAssemblyWF
    click_link_or_button 'Add workflow'
    select 'gisAssemblyWF', from: 'wf'
    click_link_or_button 'Add'
    expect(page).to have_text('Added gisAssemblyWF')
    # wait for gisAssemblyWF to finish; retry if extract-boundingbox fails in a known/retriable way
    # It will stop retrying when the passed block returns true
    reload_page_until_timeout_with_wf_step_retry!(expected_text: nil,
                                                  workflow: 'gisAssemblyWF',
                                                  workflow_retry_text: 'Error: extract-boundingbox',
                                                  retry_wait: 5) do |page|
      page.driver.with_playwright_page do |page|
        page.locator('.btn', hasText: 'Reindex').click
      end

      sleep 5

      # verify the gisAssemblyWF workflow completes
      page.has_selector?('#workflow-details-status-gisAssemblyWF', text: 'completed', wait: 1)
    end

    # (re?)verify the gisAssemblyWF workflow completes
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
    expect(files.size).to eq 9

    cells = files[0].all('td')
    expect(cells.size).to eq 9
    expect(cells[0].text).to eq 'AirMonitoringStations.shp'
    expect(cells[1].text).to eq 'application/vnd.shp'
    expect(cells[2].text).to eq '8.14 KB'

    cells = files[1].all('td')
    expect(cells.size).to eq 9
    expect(cells[0].text).to eq 'AirMonitoringStations.shx'
    expect(cells[1].text).to eq 'application/vnd.shx'
    expect(cells[2].text).to eq '2.39 KB'

    cells = files[2].all('td')
    expect(cells[0].text).to eq 'AirMonitoringStations.dbf'
    expect(cells[1].text).to eq 'application/vnd.dbf'
    expect(cells[2].text).to eq '40.8 KB'

    cells = files[3].all('td')
    expect(cells[0].text).to eq 'AirMonitoringStations.prj'
    expect(cells[1].text).to eq 'text/plain'
    expect(cells[2].text).to eq '468 Bytes'

    cells = files[4].all('td')
    expect(cells[0].text).to eq 'preview.jpg'
    expect(cells[1].text).to eq 'image/jpeg'
    expect(cells[2].text).to match '2\d.\d KB'

    cells = files[5].all('td')
    expect(cells[0].text).to eq 'AirMonitoringStations.shp.xml'
    expect(cells[1].text).to eq 'application/xml'
    expect(cells[2].text).to match '6\d.\d KB'

    cells = files[6].all('td')
    expect(cells[0].text).to eq 'AirMonitoringStations-iso19139.xml'
    expect(cells[1].text).to eq 'application/xml'
    expect(cells[2].text).to match '2\d.\d KB'

    cells = files[7].all('td')
    expect(cells[0].text).to eq 'AirMonitoringStations-iso19110.xml'
    expect(cells[1].text).to eq 'application/xml'
    expect(cells[2].text).to match '1\d.\d KB'

    cells = files[8].all('td')
    expect(cells[0].text).to eq 'AirMonitoringStations-fgdc.xml'
    expect(cells[1].text).to eq 'application/xml'
    expect(cells[2].text).to match '5.\d+ KB'

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
    expect(page).to have_text('Air Monitoring Stations: California, 2001-2003') # with the new object label
    expect(page).to have_text('This point shapefile represents all air monitoring stations active in ' \
                              'California from 2001 until 2003') # abstract
    expect(page).to have_text('cartographic') # type of resource
    expect(page).to have_text('Shapefile') # form
    expect(page).to have_text('EPSG::3310') # form for native projection
    expect(page).to have_text('Geospatial data') # genre
    expect(page).to have_text('Cartographic dataset') # genre
    # TODO: Add additional checks for GIS embed delivery on PURL?
    #  May rely on reloading geoserver layers in geoserver UI and existence of qa/stage geoservers and other complications

    # click Earthworks link and verify it was released
    click_link_or_button 'View in EarthWorks'
    reload_page_until_timeout!(text: 'Air Monitoring Stations: California, 2001-2003')
  end
end
