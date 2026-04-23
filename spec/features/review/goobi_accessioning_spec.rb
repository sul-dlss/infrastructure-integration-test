# frozen_string_literal: true

# Integration: Argo, Goobi, DSA, Purl
# NOTE: this spec will be skipped unless run on stage, since there is no goobi in QA
RSpec.describe 'Create and accession object via Goobi', if: $sdr_env == 'stage' do
  let(:druid) { test_data[:druid] }
  let(:bare_object_druid) { druid.delete_prefix('druid:') }
  let(:object_label) { test_data[:label] }
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:test_data) { load_test_data(spec_name: 'goobi_accessioning_spec') }
  let(:collection_name) { 'integration-testing' }

  before do
    authenticate!(start_url:,
                  expected_text: object_label)
  end

  after do
    clear_downloads
  end

  scenario do
    expect(page).to have_text('v1 Accessioned')

    # look for expected files
    files = all('tr.file')

    expect(files.size).to eq 2
    expect(files.first.text).to match(%r{stanford-logo.tiff image/tiff 1.\d MB})
    expect(files.last.text).to match(%r{stanford-logo.jp2 image/jp2 1\d\d KB})

    expect(find_table_cell_following(header_text: 'Content type').text).to eq('image') # filled in by accessioning

    # This section confirms the object has been published to PURL and has a
    # valid IIIF manifest
    # wait for the PURL name to be published by checking for collection name
    expect_text_on_purl_page(druid:, text: collection_name)
    expect_text_on_purl_page(druid:, text: 'This work is licensed under an Apache License 2.0')
    expect_text_on_purl_page(druid:, text: object_label)
    expect_link_on_purl_page(druid:,
                             text: 'View in SearchWorks',
                             href: "#{Settings.searchworks_url}/view/#{bare_object_druid}")
    iiif_manifest_url = find(:xpath, '//link[@rel="alternate" and @title="IIIF Manifest"]', visible: false)[:href]
    iiif_manifest = JSON.parse(Faraday.get(iiif_manifest_url).body)
    image_url = iiif_manifest.dig('sequences', 0, 'canvases', 0, 'images', 0, 'resource', '@id')
    puts "Checking that the image URL #{image_url} is accessible..."
    image_response = Faraday.get(image_url)
    expect(image_response.status).to eq(200)
    expect(image_response.headers['content-type']).to include('image/jpeg')
  end
end
