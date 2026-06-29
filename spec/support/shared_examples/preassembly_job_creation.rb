# frozen_string_literal: true

RSpec.shared_examples 'preassembly job creation' do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  # let(:bare_druid) { druid.delete_prefix('druid:') }
  let(:druid) { test_data[:druid] }
  let(:expected_text) { test_data[:title] }
  let(:test_data) { load_test_data(spec_name:) }
  let(:collection_name) { test_collection[:title] }
  let(:test_collection) { load_test_data(spec_name: 'collection_registration') }
  let(:preassembly_bundle_dir) { Settings.preassembly.bundle_directory }
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:local_file_manifest_location) { 'tmp/file_manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-#{spec_name.dasherize}-#{SecureRandom.uuid}" }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{bare_druid(druid)},content
    CSV
  end

  # Customizable parameters - can be overridden in individual specs
  let(:content_type) { 'Image' } # Image, File, Document/PDF, Media, Geo
  let(:job_type) { 'Preassembly Run' }
  let(:processing_configuration) { nil } # Optional processing configuration (e.g., 'Group by filename', 'Default')
  let(:save_job_id) { false } # Whether to save job_id to test data
  let(:navigate_to_job_details) { :click_first_link } # :click_first_link, :visit_url, or :visit_job_runs_first
  let(:use_file_manifest) { false } # Whether t choose file manifest option
  let(:ocr_settings) { nil } # Hash with OCR settings if applicable (e.g., { ocr_available: false, run_ocr: true })
  let(:stt_settings) { nil } # Hash with speech-to-text settings if applicable (e.g., { stt_available: false, run_stt: true })
  let(:sleep_after_submit) { 0 } # Optional sleep duration after submit (in seconds)
  let(:preassembly_file_manifest_csv) { nil } # Optional file manifest CSV content
  let(:cleanup_paths) { [bare_druid(druid)] } # Paths to clean up on remote host after test

  before do
    authenticate!(start_url:, expected_text:)

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    # create and copy file_manifest.csv if provided
    if preassembly_file_manifest_csv
      File.write(local_file_manifest_location, preassembly_file_manifest_csv)
      `scp #{local_file_manifest_location} #{remote_manifest_location}`
      unless $CHILD_STATUS.success?
        raise("unable to scp #{local_file_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
      end
    end
  end

  after do
    clear_downloads
    FileUtils.rm_rf(bare_druid(druid))
    unless bare_druid(druid).empty?
      cleanup_command = cleanup_paths.map { |path| "#{preassembly_bundle_dir}/#{path}" }.join(' ')
      `ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} rm -rf #{cleanup_command}`
    end
  end

  it 'creates a preassembly job and verifies the result' do
    visit Settings.preassembly.url
    expect(page).to have_css('h1', text: 'Start new job')

    sleep 1 # if you notice the project name not filling in completely, try this
    fill_in 'Project name', with: preassembly_project_name
    select job_type, from: 'Job type'
    select content_type, from: 'Content type'
    fill_in 'Staging location', with: preassembly_bundle_dir

    # Handle processing configuration if specified
    select processing_configuration, from: 'Processing configuration' if processing_configuration && !Settings.ocr.enabled

    # Handle file manifest option if applicable
    choose 'batch_context_using_file_manifest_true' if use_file_manifest

    # Handle OCR settings if provided
    if ocr_settings
      choose "batch_context_ocr_available_#{ocr_settings[:ocr_available]}" if ocr_settings.key?(:ocr_available)
      if ocr_settings.key?(:manually_corrected_ocr)
        choose "batch_context_manually_corrected_ocr_#{ocr_settings[:manually_corrected_ocr]}"
      end
      choose "batch_context_run_ocr_#{ocr_settings[:run_ocr]}" if ocr_settings.key?(:run_ocr)
      if ocr_settings[:languages]
        first('button[aria-label="toggle dropdown"]').click
        ocr_settings[:languages].each do |lang|
          check "batch_context_ocr_languages_#{lang}"
        end
      end
    end

    # Handle speech-to-text settings if provided
    if stt_settings
      choose "batch_context_stt_available_#{stt_settings[:stt_available]}" if stt_settings.key?(:stt_available)
      choose "batch_context_run_stt_#{stt_settings[:run_stt]}" if stt_settings.key?(:run_stt)
    end

    click_link_or_button 'Submit'

    # Optional sleep after submit (e.g., for OCR document spec which needs sleep 10)
    sleep sleep_after_submit if sleep_after_submit > 0

    expect(page).to have_text 'Success! Your job is queued. ' \
                              'A link to job output will be emailed to you upon completion.'

    # Get the preassembly job number
    cell = first('td', text: /^Job #\d+/)
    job_id = cell.text.match(/^Job #(\d+)/)[1]

    # Save job_id if requested
    save_test_data(spec_name:, data: test_data.merge({ 'job_id' => job_id.to_i })) if save_job_id

    # Navigate to job details page
    case navigate_to_job_details
    when :click_first_link
      first('td > a').click
      expect(page).to have_text preassembly_project_name
    when :visit_url
      visit "#{Settings.preassembly.url}/job_runs/#{job_id}"
    when :visit_job_runs_first
      visit "#{Settings.preassembly.url}/job_runs"
      first('td > a').click
      expect(page).to have_text preassembly_project_name
    end

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
  end
end
