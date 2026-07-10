# frozen_string_literal: true

require 'druid-tools'

# Integration: Argo, DSA, Preassembly, ABBYY, Purl
# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
# This spec is only run if OCR is enabled in the environment specific settings file
RSpec.describe 'Create a document object via Pre-assembly and ask for it be OCRed', if: Settings.ocr.enabled,
                                                                                    type: :preassembly do
  it_behaves_like 'preassembly job creation' do
    let(:spec_name) { 'preassembly_ocr_document' }
    let(:title) { test_data[:title] }
    let(:expected_text) { title }
    let(:preassembly_bundle_dir) { Settings.preassembly.ocr_document_bundle_directory }
    let(:content_type) { 'Document/PDF' }
    let(:ocr_settings) { { manually_corrected_ocr: false, run_ocr: true } }
    let(:sleep_after_submit) { 10 }
    let(:navigate_to_job_details) { :visit_job_runs_first }

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

      reload_page_until_timeout_with_wf_step_retry!(expected_text: /v\d+ Accessioned/, workflow: nil) do |page|
        if page.has_text?(/v\d+ Accessioned/)
          next true # done retrying, success
        elsif page.has_text?(/technical-metadata : Problem with technical-metadata-service.*-generated.pdf not found/, wait: 1)
          next 'accessionWF' # this message is for an accessionWF step
        elsif page.has_text?(/transfer-object : Error transferring bag .* for druid:/, wait: 1)
          next 'preservationIngestWF' # this message is for a preservationIngestWF step
        else
          next false # unexpected error message, will keep retrying with the last retried workflow
        end
      end

      # Check that the version description is correct for the second version
      reload_page_until_timeout!(text: 'Started OCR workflow')

      # Check that OCR was successful by looking for extra files that were created
      files = all('tr.file')

      expect(files.size).to eq 2
      expect(files[0].text).to match(%r{testocr-image-only.pdf application/pdf 9\d\d KB})
      expect(files[1].text).to match(%r{#{bare_druid(druid)}-generated.pdf application/pdf 1\d\.\d KB Transcription})

      expect(find_table_cell_following(header_text: 'Content type').text).to eq('document') # filled in by accessioning

      # check technical metadata for all non-thumbnail files
      reload_page_until_timeout! do
        click_link_or_button 'Technical metadata' # expand the Technical metadata section

        # Scroll to the bottom so the lazily-loaded tech metadata section enters the viewport
        # and the browser fetches its content.
        page.scroll_to(:bottom)

        # events are loaded lazily, give the network a few moments
        page.has_text?(/v\d+ Accessioned/, wait: 2)
      end
      page.has_text?('filetype', count: 2)
      page.has_text?('file_modification', count: 2)

      visit_argo_and_confirm_event_display!(druid:, version: version + 1)
      confirm_archive_zip_replication_events!(druid:, from_version: version, to_version: version + 1)

      # This section confirms the object has been published to PURL
      expect_text_on_purl_page(druid:, text: collection_name)
      expect_text_on_purl_page(druid:, text: title)
    end
  end
end
