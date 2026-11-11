# frozen_string_literal: true

# Integration: Argo-B3, DSA, GIS robots, Purl, Earthworks
# The files are in folders on a mount that argo-b3 can read (Settings.argo_b3_gis_deposit_directory).
# Copies of the files are in spec/fixtures/gis_integration_test_{raster,vector}.zip.
# NOTE: this spec will be skipped unless run on staging, since there is no geoserver-qa
RSpec.describe 'Use Argo-B3 to register, deposit, and release GIS items', if: $sdr_env == 'stage', type: :accessioning do
  let(:start_url) { Settings.argo_b3_url }
  let(:run_id) { SecureRandom.uuid }
  let(:collection_name) { 'Integration Test Collection - GIS' }
  # gisAssemblyWF replaces the registered title with the title from the GIS metadata.
  let(:items) do
    {
      'raster' => {
        title: 'Proposed Southern Crossings of San Francisco Bay (Raster Image)',
        abstract: 'This raster dataset is a georeferenced image',
        form: 'GeoTIFF',
        projection: 'EPSG::4326',
        files: {
          'SC_Color_WGS.tfw' => { size: /8\d Bytes/, mime_type: 'application/octet-stream' },
          # application=geotiff is added by gisAssemblyWF.
          'SC_Color_WGS.tif' => { size: /9\.\d\d MB/, mime_type: 'image/tiff; application=geotiff' },
          'SC_Color_WGS.tif.ovr' => { size: /4\.\d\d MB/, mime_type: 'application/octet-stream' },
          'SC_Color_WGS.tif.xml' => { size: /2\d\.\d KB/, mime_type: 'application/xml' },
          'SC_Color_WGS-iso19139.xml' => { size: /2\d\.\d KB/, mime_type: 'application/xml', role: 'Derivative' },
          'SC_Color_WGS-fgdc.xml' => { size: /5\.\d+ KB/, mime_type: 'application/xml', role: 'Derivative' },
          # Produced by gisDerivativeWF.
          'SC_Color_WGS_cog.tif' => { size: /4\d\.\d MB/, role: 'Derivative',
                                      mime_type: 'image/tiff; application=geotiff; profile=cloud-optimized' },
          'SC_Color_WGS.jp2' => { size: /12\d KB/, mime_type: 'image/jp2', role: 'Thumbnail' }
        }
      },
      'vector' => {
        title: 'Air Monitoring Stations: California, 2001-2003',
        abstract: 'This point shapefile represents all air monitoring stations active in California from 2001 until 2003',
        form: 'Shapefile',
        projection: 'EPSG::3310',
        files: {
          'AirMonitoringStations.dbf' => { size: /40\.8 KB/, mime_type: 'application/x-dbf' },
          'AirMonitoringStations.prj' => { size: /468 Bytes/, mime_type: 'text/plain' },
          'AirMonitoringStations.shp' => { size: /8\.14 KB/, mime_type: 'application/vnd.shp' },
          'AirMonitoringStations.shp.xml' => { size: /6\d\.\d KB/, mime_type: 'application/xml' },
          'AirMonitoringStations.shx' => { size: /2\.39 KB/, mime_type: 'application/octet-stream' },
          'AirMonitoringStations-iso19139.xml' => { size: /2\d\.\d KB/, mime_type: 'application/xml', role: 'Derivative' },
          'AirMonitoringStations-iso19110.xml' => { size: /1\d\.\d KB/, mime_type: 'application/xml', role: 'Derivative' },
          'AirMonitoringStations-fgdc.xml' => { size: /5\.\d+ KB/, mime_type: 'application/xml', role: 'Derivative' },
          # Produced by gisDerivativeWF.
          'AirMonitoringStations.fgb' => { size: /68\.\d+ KB/, mime_type: 'application/vnd.fgb', role: 'Derivative' },
          'AirMonitoringStations.pmtiles' => { size: /42 KB/, mime_type: 'application/vnd.pmtiles', role: 'Derivative' },
          'AirMonitoringStations.jp2' => { size: /85\.\d KB/, mime_type: 'image/jp2', role: 'Thumbnail' }
        }
      }
    }
  end
  # The source files, before GIS workflows add metadata and derivatives.
  let(:source_file_counts) { { 'raster' => 4, 'vector' => 5 } }
  # Populated by registration, keyed like items.
  let(:druids) { {} }

  before do
    authenticate!(start_url:, expected_text: 'Argo dashboard')
  end

  scenario do
    ## Step 1: Register the items using the Register multiple items form
    click_link_or_button 'Register multiple items', exact: true
    expect(page).to have_css('h1', text: 'Register items')
    fill_in_registration_settings
    fill_in_items
    click_button 'Register items'

    registered = registered_druids(source_ids: items.keys.map { |key| source_id(key) })
    items.each_key do |key|
      druids[key] = registered.fetch(source_id(key))
      puts " *** argo-b3 GIS deposit #{key} druid: #{druids[key]} ***"
    end

    ## Step 2: Deposit the items
    deposit_multiple_items(description: "argo-b3 GIS deposit #{run_id}",
                           mount_path: Settings.argo_b3_gis_deposit_directory,
                           folders: items.keys.to_h do |key|
                             [druids[key], { folder: key, file_count: source_file_counts.fetch(key) }]
                           end,
                           deposit_type: 'new item')

    items.each do |key, item|
      ## Step 3: Verify the GIS workflows and accessioning in Argo-B3
      expect_accessioned_on_object_page(druid: druids[key])
      expect_file_details_on_object_page(druid: druids[key], files: item[:files])

      ## Step 4: Verify the description published to PURL
      expect_published_description(druid: druids[key], item:)

      ## Step 5: Release to Earthworks and verify the release
      release_to_earthworks(druid: druids[key])
      expect_released_to_earthworks(druid: druids[key], title: item[:title])
    end
  end

  def source_id(key)
    "argo-b3-gis-deposit:#{run_id}-#{key}"
  end

  def fill_in_registration_settings
    select 'geo', from: 'Content type'
    select 'APO for GIS', from: 'APO'

    collection_input = find_field(placeholder: 'Start typing the collection name or druid...')
    collection_input.fill_in(with: collection_name)
    find('.ts-dropdown .option', text: collection_name).click
    expect(page).to have_css('.ts-control .item', text: collection_name)

    # Set after selecting the APO (and the collection, which waits on autocomplete), so that the APO defaults
    # applied on selection don't overwrite them.
    select 'World', from: 'View access'
    select 'World', from: 'Download access'
  end

  def fill_in_items
    choose 'Enter each item individually. Either FOLIO Instance HRID or Title is required.'
    within('#item-registrations') do
      items.each_key.with_index do |key, index|
        if index.positive?
          click_button 'Add another item'
          expect(page).to have_css('.form-instance', count: index + 1)
        end
        within(all('.form-instance').last) do
          fill_in 'Source ID', with: source_id(key)
          fill_in 'Title', with: "argo-b3 GIS deposit #{key} #{random_phrase}"
        end
      end
    end
  end

  # The object page doesn't refresh itself as workflows progress, so reloads until each is complete.
  def expect_accessioned_on_object_page(druid:)
    visit "#{start_url}/objects/#{druid}"
    %w[gisAssemblyWF gisDerivativeWF accessionWF].each do |workflow|
      reload_page_until_timeout! do
        # The workflows turbo-frame is lazily loaded when the tab is shown.
        find_by_id('workflows-tab').click
        within('#workflows-pane') do
          page.has_css?('.collapsible-section-toggle', text: /#{workflow}\s+Complete/, wait: 5)
        end
      end
    end

    # Status is from Solr, so may lag the workflows.
    reload_page_until_timeout! { page.has_css?('#overview-table tr', text: /Status\s+v1 Accessioned/, wait: 1) }
    expect(page).to have_css('#overview-table tr', text: /Content type\s+Geo/)
  end

  def expect_published_description(druid:, item:)
    # Waits for the version to be published.
    published_cocina_filenames(druid:, version: 1)
    cocina_json = JSON.parse(Faraday.get("#{Settings.purl_url}/#{bare_druid(druid)}.json").body)
    expect(cocina_json['label']).to eq item[:title]

    description = cocina_json['description']
    expect(description['title'].first['value']).to eq item[:title]
    expect(description['note'].find { |note| note['type'] == 'abstract' }['value']).to include(item[:abstract])
    forms = description['form']
    expect(forms).to include(a_hash_including('type' => 'resource type', 'value' => 'cartographic'))
    expect(forms).to include(a_hash_including('type' => 'form', 'value' => item[:form]))
    expect(forms.find { |form| form['type'] == 'map projection' }['value']).to eq item[:projection]
    expect(forms).to include(a_hash_including('type' => 'genre', 'value' => 'Geospatial data'))
    expect(forms).to include(a_hash_including('type' => 'genre', 'value' => 'cartographic dataset'))
  end

  def release_to_earthworks(druid:)
    visit "#{start_url}/objects/#{druid}"
    # Both the Actions button and the release box's edit icon are labelled Manage release.
    click_link_or_button 'Manage release', match: :first
    expect(page).to have_css('h1', text: 'Manage release')
    select 'Release', from: 'EarthWorks'
    click_button 'Save'
    expect(page).to have_text('Release updated')
  end

  def expect_released_to_earthworks(druid:, title:)
    reload_page_until_timeout! { page.has_link?('Earthworks', href: /stanford-#{bare_druid(druid)}/, wait: 1) }

    expect_link_on_purl_page(druid:,
                             text: 'View in EarthWorks',
                             href: "#{Settings.earthworks_url}/stanford-#{bare_druid(druid)}")
    click_link_or_button 'View in EarthWorks'
    reload_page_until_timeout!(text: title)
  end
end
