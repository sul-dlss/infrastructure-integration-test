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
      click_link_or_button 'Reindex'
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
    expect(files[0].text).to match(%r{AirMonitoringStations.shp application/vnd.shp 8.14 KB})
    expect(files[1].text).to match(%r{AirMonitoringStations.shx application/vnd.shx 2.39 KB})
    expect(files[2].text).to match(%r{AirMonitoringStations.dbf application/vnd.dbf 40.8 KB})
    expect(files[3].text).to match(%r{AirMonitoringStations.prj text/plain 468 Bytes})
    expect(files[4].text).to match(%r{preview.jpg image/jpeg 2\d.\d KB})
    expect(files[5].text).to match(%r{AirMonitoringStations.shp.xml application/xml 6\d.\d KB})
    expect(files[6].text).to match(%r{AirMonitoringStations-iso19139.xml application/xml 2\d.\d KB})
    expect(files[7].text).to match(%r{AirMonitoringStations-iso19110.xml application/xml 1\d.\d KB})
    expect(files[8].text).to match(%r{AirMonitoringStations-fgdc.xml application/xml 5.\d+ KB})

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

    # This section confirms the cocina JSON has been published to PURL
    cocina_json = JSON.parse(Faraday.get("#{Settings.purl_url}/#{bare_druid}.json").body)
    description = cocina_json['description']
    expect(cocina_json['label']).to eq 'Air Monitoring Stations: California, 2001-2003'
    resource_types = description['form'].select { |form| form['type'] == 'resource type' }
    expect(resource_types.any? { |resource| resource['value'] == 'cartographic' }).to be true
    expect(description['title'].first['value']).to eq 'Air Monitoring Stations: California, 2001-2003' # with the new object label
    expect(description['note'].select { |note| note['type'] == 'abstract' }.first['value']) # abstract
      .to include('This point shapefile represents all air monitoring stations active in California from 2001 until 2003')
    forms = description['form'].select { |form| form['type'] == 'form' }
    expect(forms.any? { |resource| resource['value'] == 'Shapefile' }).to be true # form
    expect(description['form'].select { |form| form['type'] == 'map projection' }.first['value'])
      .to eq 'EPSG::3310' # form for native projection
    genres = description['form'].select { |form| form['type'] == 'genre' }
    expect(genres.any? { |genre| genre['value'] == 'Geospatial data' }).to be true
    expect(genres.any? { |genre| genre['value'] == 'cartographic dataset' }).to be true

    # wait for the PURL name to be published by checking for collection name and check for bits of expected metadata
    expect_text_on_purl_page(druid:, text: collection_name)
    expect_link_on_purl_page(druid:,
                             text: 'View in EarthWorks',
                             href: "#{Settings.earthworks_url}/stanford-#{bare_druid}")
    expect(page).to have_no_text(object_label) # the original object label has been replaced
    # click Earthworks link and verify it was released
    click_link_or_button 'View in EarthWorks'
    reload_page_until_timeout!(text: 'Air Monitoring Stations: California, 2001-2003')
  end
end
