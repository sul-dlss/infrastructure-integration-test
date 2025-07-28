# frozen_string_literal: true

require 'druid-tools'

# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly.host at Settings.preassembly.bundle_directory
# This spec is only run if OCR is enabled in the environment specific settings file
RSpec.describe 'Create a document object via Pre-assembly and ask for it be OCRed', if: Settings.ocr.enabled do
  bare_druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:preassembly_bundle_dir) { Settings.preassembly.ocr_document_bundle_directory } # where we will stage the ocr content
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-preassembly-document-ocr-#{random_noun}-#{random_alpha}" }
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "document-ocr-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "document ocr integration test #{label_random_words}" }
  let(:collection_name) { 'integration-testing' }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{bare_druid},content
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
    select 'document', from: 'Content Type'
    fill_in 'Project Name', with: 'Integration Test - Document OCR via Preassembly'
    fill_in 'Source ID', with: "#{source_id}-#{random_alpha}"
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_druid = find('table a').text
    druid = "druid:#{bare_druid}"
    puts " *** preassembly document accessioning druid: #{druid} ***" # useful for debugging

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    visit Settings.preassembly.url
    expect(page).to have_css('h1', text: 'Start new job')

    sleep 1 # if you notice the project name not filling in completely, try this to
    #           give the page a moment to load so we fill in the full text field
    fill_in 'Project name', with: preassembly_project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Document/PDF', from: 'Content type'
    fill_in 'Staging location', with: preassembly_bundle_dir
    choose 'batch_context_manually_corrected_ocr_false' # indicate documents do not have pre-existing OCR
    choose 'batch_context_run_ocr_true' # yes, run OCR

    click_link_or_button 'Submit'
    sleep 10
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
    yaml = YAML.load_file(download)
    puts "Download is #{download}: #{File.read(download)}"
    expect(yaml[:status]).to eq 'success'
    # delete the downloaded YAML file, so we don't pick it up by mistake during the re-accession
    delete_download(download)

    # ensure accessioning completed ... we should have two versions now,
    # with all files there, and an ocrWF, organized into specified resources
    visit "#{Settings.argo_url}/view/#{druid}"

    # Check that ocrWF ran
    reload_page_until_timeout!(text: 'ocrWF')

    # Wait for the second version accessioningWF to finish
    reload_page_until_timeout!(text: 'v2 Accessioned')

    # Check that the version description is correct for the second version
    reload_page_until_timeout!(text: 'Start OCR workflow')

    # TODO: check that OCR was successful by looking for extra files that were created, and update expectations below

    files = all('tr.file')

    expect(files.size).to eq 2
    expect(files[0].text).to match(%r{testocr-image-only.pdf application/pdf 9\d\d KB})
    expect(files[1].text).to match(%r{#{bare_druid}-generated.pdf application/pdf 1\d\.\d KB Transcription})

    expect(find_table_cell_following(header_text: 'Content type').text).to eq('document') # filled in by accessioning

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
    page.has_text?('filetype', count: 2)
    page.has_text?('file_modification', count: 2)

    visit_argo_and_confirm_event_display!(druid:, version: 2)
    confirm_archive_zip_replication_events!(druid:, from_version: 1, to_version: 2)

    # This section confirms the object has been published to PURL
    expect_text_on_purl_page(druid:, text: collection_name)
    expect_text_on_purl_page(druid:, text: object_label)
  end
end
