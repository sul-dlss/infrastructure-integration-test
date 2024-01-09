# frozen_string_literal: true

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
    select 'file', from: 'Content Type'
    fill_in 'Project Name', with: project_name
    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    puts " *** GIS accessioning druid: #{bare_object_druid} ***" # useful for debugging
    druid = "druid:#{bare_object_druid}"

    # Go to kurma server and copy test content to the druid folder so it can be accessioned
    # Should this test data be deleted from the server,
    # a zipped copy is available at spec/fixtures/gis_integration_test_data.zip
    test_data_source_folder = File.join(Settings.gis.robots_content_root, 'integration_test_data')
    test_data_destination_folder = File.join(Settings.gis.robots_content_root, bare_object_druid, 'temp')
    copy_command = "ssh #{Settings.gis.username}@#{Settings.gis.robots_host} " \
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
    reload_page_until_timeout_with_wf_step_retry!(expected_text: nil,
                                                  workflow: 'gisAssemblyWF',
                                                  workflow_retry_text: 'Error: extract-boundingbox',
                                                  retry_wait: 5) do |page|
      click_link_or_button 'Reindex'
      sleep 5
      !page.has_text?('Error: extract-boundingbox')
    end
    # verify the workflow completes
    reload_page_until_timeout! do
      page.has_selector?('#workflow-details-status-gisAssemblyWF', text: 'completed', wait: 1)
    end

    # add gisDeliveryWF
    click_link_or_button 'Add workflow'
    select 'gisDeliveryWF', from: 'wf'
    click_link_or_button 'Add'
    expect(page).to have_text('Added gisDeliveryWF')
    # manually set the "reset geowebcache" step to completed
    #  because of an existing bug: https://github.com/sul-dlss/gis-robot-suite/issues/401
    #  we can remove when no longer needed  7/29/2022
    click_link_or_button 'gisDeliveryWF'
    click_link_or_button 'workflow-status-set-reset-geowebcache-completed'
    # verify the workflow completes
    reload_page_until_timeout! do
      page.has_selector?('#workflow-details-status-gisDeliveryWF', text: 'completed', wait: 1)
    end

    # add accessionWF
    click_link_or_button 'Add workflow'
    select 'accessionWF', from: 'wf'
    click_link_or_button 'Add'
    expect(page).to have_text('Added accessionWF')
    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    # look for expected files produced by GIS workflows
    files = all('tr.file')
    expect(files.size).to eq 3
    expect(files[0].text).to match(%r{data.zip application/zip 5\d.\d KB})
    expect(files[1].text).to match(%r{data_EPSG_4326.zip application/zip 2\d KB})
    expect(files[2].text).to match(%r{preview.jpg image/jpeg 2\d.\d KB})

    # verify that the content type was switched from "file" to "geo" by the GIS workflows
    expect(find_table_cell_following(header_text: 'Content type').text).to eq('geo')

    # This section confirms the object has been published to PURL
    # wait for the PURL name to be published by checking for collection name and check for bits of expected metadata
    expect_text_on_purl_page(druid:, text: collection_name)
    expect_link_on_purl_page(druid:,
                             text: 'View in EarthWorks',
                             href: "https://earthworks.stanford.edu/catalog/stanford-#{bare_object_druid}")
    expect_text_on_purl_page(druid:, text: 'This point shapefile represents all air monitoring stations active in ' \
                                           'California from 2001 until 2003')
    expect(page).to have_no_text(object_label) # the original object label has been replaced
    expect(page).to have_text('Air Monitoring Stations: California, 2001-2003') # with the new object label
    expect(page).to have_text('cartographic') # type of resource
    expect(page).to have_text('Shapefile') # form
    expect(page).to have_text('Scale not given ; EPSG::4326') # map data
    expect(page).to have_text('Geospatial data') # genre
    expect(page).to have_text('Cartographic dataset') # genre
    expect(page).to have_link('View in EarthWorks') # link to Earthworks
    # TODO: Add additional checks for GIS embed delivery on PURL?
    #  May rely on reloading geoserver layers in geoserver UI and existence of qa/stage geoservers and other complications
  end
end
