# frozen_string_literal: true

require 'druid-tools'

# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
# This spec is only run if speech_to_text is enabled in the environment specific settings file
RSpec.describe 'Create a media object via Pre-assembly and ask for it be speechToTexted', if: Settings.speech_to_text.enabled do
  bare_druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:preassembly_bundle_dir) { Settings.preassembly.speech_to_text_bundle_directory } # where we will stage the media content
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:local_file_manifest_location) { 'tmp/file_manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-preassembly-media-stt-#{random_noun}-#{random_alpha}" }
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "media-stt-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "media stt integration test #{label_random_words}" }
  let(:collection_name) { 'integration-testing' }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{bare_druid},content
    CSV
  end
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

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  after do
    clear_downloads
    FileUtils.rm_rf(bare_druid)
    unless bare_druid.empty?
      `ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} rm -rf \
      #{preassembly_bundle_dir}/#{bare_druid}`
    end
  end

  scenario do
    select 'integration-testing', from: 'Admin Policy'
    select collection_name, from: 'Collection'
    select 'media', from: 'Content Type'
    fill_in 'Project Name', with: 'Integration Test - Media Speech To Text via Preassembly'
    fill_in 'Source ID', with: "#{source_id}-#{random_alpha}"
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_druid = find('table a').text
    druid = "druid:#{bare_druid}"
    puts " *** preassembly media accessioning druid: #{druid} ***" # useful for debugging

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    # create file_manifest.csv file and scp it to preassembly staging directory
    File.write(local_file_manifest_location, preassembly_file_manifest_csv)
    `scp #{local_file_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_file_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    visit Settings.preassembly.url
    expect(page).to have_css('h1', text: 'Start new job')

    sleep 1 # if you notice the project name not filling in completely, try this to
    #           give the page a moment to load so we fill in the full text field
    fill_in 'Project name', with: preassembly_project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Media', from: 'Content type'
    fill_in 'Staging location', with: preassembly_bundle_dir
    choose 'batch_context_stt_available_false' # indicate media does not have pre-existing speech to text
    choose 'batch_context_run_stt_true' # yes, run speech to text
    # Note: for media, file manifest is automatically selected with no radio button

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
    puts "Download is #{download}: #{File.read(download)}"
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'
    # delete the downloaded YAML file, so we don't pick it up by mistake during the re-accession
    delete_download(download)

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

      # this is a hack that forces the tech metadata section to scroll into view; the section
      # is lazily loaded, and won't actually be requested otherwise, even if the button
      # is clicked to expand the event section.
      page.execute_script 'window.scrollBy(0,100);'

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
