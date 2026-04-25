# frozen_string_literal: true

RSpec.shared_examples 'preassembly job creation' do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:bare_druid) { druid.delete_prefix('druid:') }
  let(:druid) { test_data[:druid] }
  let(:expected_text) { test_data[:title] }
  let(:test_data) { load_test_data(spec_name:) }
  let(:preassembly_bundle_dir) { Settings.preassembly.bundle_directory }
  let(:remote_manifest_location) do
    "#{Settings.preassembly.username}@#{Settings.preassembly.host}:#{preassembly_bundle_dir}"
  end
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-#{spec_name.dasherize}-#{SecureRandom.uuid}" }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{bare_druid},content
    CSV
  end

  before do
    authenticate!(start_url:, expected_text:)

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end
  end

  after do
    clear_downloads
    FileUtils.rm_rf(bare_druid)
    unless bare_druid.empty?
      `ssh #{Settings.preassembly.username}@#{Settings.preassembly.host} rm -rf \
      #{preassembly_bundle_dir}/#{bare_druid}`
    end
  end

  it 'creates a preassembly job and verifies the result' do
    visit Settings.preassembly.url
    expect(page).to have_css('h1', text: 'Start new job')

    sleep 1 # if you notice the project name not filling in completely, try this
    fill_in 'Project name', with: preassembly_project_name
    select 'Preassembly Run', from: 'Job type'
    select 'Image', from: 'Content type'
    fill_in 'Staging location', with: preassembly_bundle_dir

    click_link_or_button 'Submit'
    expect(page).to have_text 'Success! Your job is queued. ' \
                              'A link to job output will be emailed to you upon completion.'

    # Get the preassembly job number
    cell = first('td', text: /^Job #\d+/)
    job_id = cell.text.match(/^Job #(\d+)/)[1]

    save_test_data(spec_name:, data: test_data.merge({ 'job_id' => job_id.to_i }))

    # go to job details page, download result
    # first('td > a').click
    # expect(page).to have_text preassembly_project_name
    visit "#{Settings.preassembly.url}/job_runs/#{job_id}"

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
