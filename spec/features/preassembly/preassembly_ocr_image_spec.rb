# frozen_string_literal: true

require 'druid-tools'

# Integration: Argo, DSA, Preassembly, ABBYY, Purl, Earthworks
# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
# This spec is only run if OCR is enabled in the environment specific settings file
RSpec.describe 'Create an image object via Pre-assembly and ask for it be OCRed', if: Settings.ocr.enabled, type: :preassembly do
  it_behaves_like 'preassembly job creation' do
    let(:spec_name) { 'preassembly_ocr_image' }
    let(:object_label) { test_data[:title] }
    let(:expected_text) { object_label }
    let(:preassembly_bundle_dir) { Settings.preassembly.ocr_bundle_directory }
    let(:content_type) { 'Image' }
    let(:ocr_settings) { { ocr_available: false, run_ocr: true } }
    let(:navigate_to_job_details) { :click_first_link }
    let(:sleep_after_submit) { 300 } # Sleep for 5 minutes after submitting the job for OCR to run

    after do
      # Additional verification after the shared example completes
      # ensure accessioning completed ... we should have two versions now,
      # with all files there, and an ocrWF, organized into specified resources
      visit "#{Settings.argo_url}/view/#{druid}"

      # Check that ocrWF ran
      reload_page_until_timeout!(text: 'ocrWF')

      # Wait for the new version accessioningWF to finish
      elem = find_table_cell_following(header_text: 'Status')
      md = /^v(\d+) *./.match(elem.text)
      version = md[1].to_i

      # This can take a while if Abbyy is busy
      reload_page_until_timeout!(text: /v\d+ Accessioned/, num_seconds: 15 * 60)

      # Check that the version description is correct for the second version
      reload_page_until_timeout!(text: 'Started OCR workflow')

      # Check that OCR was successful by looking for extra files that were created
      files = all('tr.file')

      expect(files.size).to eq 8
      expect(files[0].text).to match(%r{testocr.tiff image/tiff 1.1\d MB})
      expect(files[1].text).to match(%r{testocr.jp2 image/jp2 95\.*\d* KB})
      expect(files[2].text).to match(%r{testocr.xml application/xml 9\.*\d* KB Transcription})

      expect(files[3].text).to match(%r{testocr2.tiff image/tiff 177 KB})
      expect(files[4].text).to match(%r{testocr2.jp2 image/jp2 25\.*\d* KB})
      expect(files[5].text).to match(%r{testocr2.xml application/xml \d\.*\d* KB Transcription})

      expect(files[6].text).to match(%r{#{bare_druid(druid)}.pdf application/pdf 1\d\.*\d* KB Transcription})
      expect(files[7].text).to match(%r{#{bare_druid(druid)}.txt text/plain 5\d\d Bytes No role})

      expect(find_table_cell_following(header_text: 'Content type').text).to eq('image') # filled in by accessioning

      # check technical metadata for all non-thumbnail files
      reload_page_until_timeout! do
        click_link_or_button 'Technical metadata' # expand the Technical metadata section

        # Scroll to the bottom so the lazily-loaded tech metadata section enters the viewport
        # and the browser fetches its content.
        page.scroll_to(:bottom)

        # events are loaded lazily, give the network a few moments
        page.has_text?(/v\d+ Accessioned/, wait: 2)
      end
      page.has_text?('filetype', count: 6)
      page.has_text?('file_modification', count: 6)

      visit_argo_and_confirm_event_display!(druid:, version: version)
      confirm_archive_zip_replication_events!(druid:, from_version: version - 1, to_version: version)

      # This section confirms the object has been published to PURL and has a
      # valid IIIF manifest
      # wait for the PURL name to be published by checking for collection name
      expect_text_on_purl_page(druid:, text: collection_name)
      expect_text_on_purl_page(druid:, text: object_label)
      iiif_manifest_url = find(:xpath, '//link[@rel="alternate" and @title="IIIF Manifest"]', visible: false)[:href]
      iiif_manifest = JSON.parse(Faraday.get(iiif_manifest_url).body)
      image_url = iiif_manifest.dig('sequences', 0, 'canvases', 0, 'images', 0, 'resource', '@id')
      image_response = Faraday.get(image_url)
      expect(image_response.status).to eq(200)
      expect(image_response.headers['content-type']).to include('image/jpeg')
    end
  end
end
