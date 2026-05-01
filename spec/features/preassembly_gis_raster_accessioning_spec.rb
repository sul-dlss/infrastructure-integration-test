# frozen_string_literal: true

# Integration: Argo, DSA, Preassembly, Purl, Earthworks
# Use pre-assembly to accession a raster based GIS object
# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.gis.robots_content_root
# NOTE: this spec will be skipped unless run on staging, since there is no geoserver-qa
RSpec.describe 'Create gis object via Pre-assembly', if: $sdr_env == 'stage', type: :accessioning do
  it_behaves_like 'preassembly job creation' do
    let(:spec_name) { 'preassembly_gis_raster_accessioning' }
    let(:object_label) { test_data[:title] }
    let(:expected_text) { object_label }
    let(:preassembly_bundle_dir) { Settings.preassembly.gis_bundle_directory }
    let(:content_type) { 'Geo' }
    let(:navigate_to_job_details) { :click_first_link }
    let(:cleanup_paths) { ['content', 'manifest.csv'] }
    let(:collection_name) { 'Integration Test Collection - GIS' }

    before do
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
    end

    after do
      # Additional verification after the shared example completes
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
      expect(page).to have_text("Updated release for #{druid}")

      # This section confirms the object has been published to PURL
      # wait for the PURL name to be published by checking for collection name and check for bits of expected metadata
      expect_text_on_purl_page(druid:, text: collection_name)
      expect_link_on_purl_page(druid:,
                               text: 'View in EarthWorks',
                               href: "#{Settings.earthworks_url}/stanford-#{bare_druid}")

      # This section confirms the cocina JSON has been published to PURL
      cocina_json = JSON.parse(Faraday.get("#{Settings.purl_url}/#{bare_druid}.json").body)
      description = cocina_json['description']
      expect(cocina_json['label']).to eq 'Proposed Southern Crossings of San Francisco Bay (Raster Image)'
      resource_types = description['form'].select { |form| form['type'] == 'resource type' }
      expect(resource_types.any? { |resource| resource['value'] == 'cartographic' }).to be true
      expect(description['title'].first['value']).to eq 'Proposed Southern Crossings of San Francisco Bay (Raster Image)'
      expect(description['note'].select { |note| note['type'] == 'abstract' }.first['value']) # abstract
        .to include('This raster dataset is a georeferenced image')
      forms = description['form'].select { |form| form['type'] == 'form' }
      expect(forms.any? { |resource| resource['value'] == 'GeoTIFF' }).to be true # form
      expect(description['form'].select { |form| form['type'] == 'map projection' }.first['value'])
        .to eq 'EPSG::4326' # form for native projection
      genres = description['form'].select { |form| form['type'] == 'genre' }
      expect(genres.any? { |genre| genre['value'] == 'Geospatial data' }).to be true
      expect(genres.any? { |genre| genre['value'] == 'cartographic dataset' }).to be true

      # click Earthworks link and verify it was released
      click_link_or_button 'View in EarthWorks'
      reload_page_until_timeout!(text: 'Proposed Southern Crossings of San Francisco Bay (Raster Image)')
    end
  end
end
