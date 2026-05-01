# frozen_string_literal: true

require 'druid-tools'

# Integration: Argo, DSA, Preassembly, Speech-to-Text, Purl
# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
# This spec is only run if speech_to_text is enabled in the environment specific settings file
RSpec.describe 'Create a media object via Pre-assembly and ask for it be speechToTexted', if: Settings.speech_to_text.enabled,
                                                                                          type: :accessioning do
  it_behaves_like 'preassembly job creation' do
    let(:spec_name) { 'preassembly_speech_to_text' }
    let(:object_label) { test_data[:title] }
    let(:expected_text) { object_label }
    let(:preassembly_bundle_dir) { Settings.preassembly.speech_to_text_bundle_directory }
    let(:content_type) { 'Media' }
    let(:stt_settings) { { stt_available: false, run_stt: true } }
    let(:navigate_to_job_details) { :click_first_link }
    let(:collection_name) { 'integration-testing' }
    let(:preassembly_file_manifest_csv) do
      <<~CSV
        druid,filename,resource_label,sequence,publish,preserve,shelve,resource_type,role,sdr_generated_text,corrected_for_accessibility
        content,video_1.mp4,Video file 1,1,yes,yes,yes,video,,,
        content,video_1_thumb.jp2,Video file 1,1,yes,yes,yes,image,,,
        content,audio_1.m4a,Audio file 1,2,yes,yes,yes,audio,,,
        content,audio_1_thumb.jp2,Video file 2,2,yes,yes,yes,image,,,
        content,video_log.txt,Disc log file,5,no,yes,no,file,,,
      CSV
    end

    after do
      # Additional verification after the shared example completes
      # ensure accessioning completed ... we should have two versions now,
      # with all files there, and a speechToTextWF, organized into specified resources
      visit "#{Settings.argo_url}/view/#{druid}"

      # Check that speechToTextWF ran
      reload_page_until_timeout!(text: 'speechToTextWF')

      # Wait for the second version accessioningWF to finish -- this can take longer
      # than normal due to the captioning process in AWS taking longer
      reload_page_until_timeout!(text: 'v2 Accessioned', num_seconds: 1200)

      # Check that the version description is correct for the second version
      reload_page_until_timeout!(text: 'Start SpeechToText workflow')

      # TODO: check that OCR was successful by looking for extra files that were created, and update expectations below

      files = all('tr.file')

      expect(files.size).to eq 11
      expect(files[0].text).to match(%r{video_1.mp4 video/mp4 9.9\d* MB})
      expect(files[1].text).to match(%r{video_1_thumb.jp2 image/jp2 4\d.\d* KB})
      expect(files[2].text).to match(%r{video_1_mp4.json application/json \d\d.\d* KB})
      expect(files[3].text).to match(%r{video_1_mp4.txt text/plain \d.\d* KB})
      expect(files[4].text).to match(%r{video_1_mp4.vtt text/vtt \d.\d* KB})

      expect(files[5].text).to match(%r{audio_1.m4a audio/mp4 4.6\d* MB})
      expect(files[6].text).to match(%r{audio_1_thumb.jp2 image/jp2 3\d.\d* KB})
      expect(files[7].text).to match(%r{audio_1_m4a.json application/json \d\d.\d* KB})
      expect(files[8].text).to match(%r{audio_1_m4a.txt text/plain \d.\d* KB Transcription})
      expect(files[9].text).to match(%r{audio_1_m4a.vtt text/vtt \d.\d* KB Caption})

      expect(files[10].text).to match(%r{video_log.txt text/plain 5\d* Bytes No role})

      # TODO: Add expectations for the speech to text files when they are added to the object
      #
      expect(find_table_cell_following(header_text: 'Content type').text).to eq('media') # filled in by accessioning

      # check technical metadata for all non-thumbnail files
      reload_page_until_timeout! do
        click_link_or_button 'Technical metadata' # expand the Technical metadata section

        # Scroll to the bottom so the lazily-loaded tech metadata section enters the viewport
        # and the browser fetches its content.
        page.scroll_to(:bottom)

        # events are loaded lazily, give the network a few moments
        page.has_text?('v2 Accessioned', wait: 2)
      end
      page.has_text?('filetype', count: 11)
      page.has_text?('file_modification', count: 11)

      visit_argo_and_confirm_event_display!(druid:, version: 2)
      confirm_archive_zip_replication_events!(druid:, from_version: 1, to_version: 2)

      # This section confirms the object has been published to PURL and has a
      # valid IIIF manifest
      # wait for the PURL name to be published by checking for collection name
      expect_text_on_purl_page(druid:, text: collection_name)
      expect_text_on_purl_page(druid:, text: object_label)
      iiif_manifest_url = find(:xpath, '//link[@rel="alternate" and @title="IIIF Manifest"]', visible: false)[:href]
      iiif_manifest = JSON.parse(Faraday.get(iiif_manifest_url).body)
      expect(iiif_manifest['label']['en'].first).to eq object_label
    end
  end
end
