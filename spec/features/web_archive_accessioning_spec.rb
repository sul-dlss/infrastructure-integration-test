# frozen_string_literal: true

RSpec.describe 'Use was-registrar-app, Argo, and pywb to ensure web archive crawl and seed accession', type: :feature do
  let(:job_specific_directory) { start_time.to_i.to_s }
  let(:remote_path) do
    "#{Settings.was_registrar.username}@#{Settings.was_registrar.host}:#{Settings.was_registrar.jobs_directory}/" \
      "#{job_specific_directory}/"
  end
  let(:collection_name) { 'Test Pywb Web Archive' }
  let(:start_time) { Time.now }
  let(:source_id) { "test:#{start_time.to_i}" }
  let(:start_url) { "#{Settings.was_registrar.url}/registration_jobs/new" }
  let(:warc_path) { 'spec/fixtures/data.warc' }
  let(:updated_warc) do
    Tempfile.new([job_specific_directory, '.warc']).tap do |file|
      original_warc = File.read(warc_path)
      updated_warc = original_warc.lines
                                  .map do |line|
        line.start_with?('WARC-Date') ? "WARC-Date: #{start_time.utc.iso8601(3)}\r\n" : line
      end.join
      file.write(updated_warc)
      file.close
    end
  end
  let(:url_in_wayback) { 'https://library.stanford.edu/department/digital-library-systems-and-services-dlss/about-us' }
  let(:archived_url) { "#{Settings.was_playback_url}/*/#{url_in_wayback}" }

  before do
    `ssh #{Settings.was_registrar.username}@#{Settings.was_registrar.host} mkdir -p \
         #{Settings.was_registrar.jobs_directory}/#{job_specific_directory}`
    raise("unable to create job directory: #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    `scp #{updated_warc.path} #{remote_path}`
    raise("unable to scp #{updated_warc_path} to #{remote_path}: #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    authenticate!(start_url: start_url, expected_text: 'New one-time registration')
  end

  scenario do
    # Crawl
    fill_in 'Job directory', with: job_specific_directory
    fill_in 'Collection Druid', with: Settings.default_collection
    fill_in 'Source ID', with: source_id
    click_button 'Create Registration job'

    expect(page).to have_content('Queueing one-time registration.')

    # wait for registration to complete
    reload_page_until_timeout!(text: 'success: Created', table: { 'Job directory' => job_specific_directory })

    crawl_druid = find(:table_row, { 'Job directory' => job_specific_directory }).text.split.last
    puts " *** was crawl druid: #{crawl_druid} ***" # useful for debugging
    visit "#{Settings.argo_url}/view/#{crawl_druid}"

    expect(page).to have_content(job_specific_directory)

    content_type_element = find_table_cell_following(header_text: 'Content type')
    expect(content_type_element.text).to eq('webarchive-binary')

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    expect(page).to have_link('wasCrawlPreas')

    visit "#{Settings.was_playback_url}/was/#{start_time.strftime('%Y%m%d%H%M%S')}/#{url_in_wayback}"
    expect(page).to have_content('About us | Stanford Libraries')

    # Seed
    visit "#{Settings.argo_url}/registration"
    select 'Web Archive Seed Object APO', from: 'Admin Policy'
    select collection_name, from: 'Collection'
    select 'wasSeedPreassemblyWF', from: 'Initial Workflow'
    select 'webarchive-seed', from: 'Content Type'
    fill_in 'Source ID', with: "seed-#{source_id}"
    fill_in 'Label', with: url_in_wayback
    fill_in 'Tags', with: 'webarchive : seed'
    click_button 'Register'

    expect(page).to have_text 'Items successfully registered.'

    seed_druid = find('table a').text
    full_seed_druid = "druid:#{seed_druid}"
    puts " *** was seed druid: #{full_seed_druid} ***" # useful for debugging

    visit "#{Settings.argo_url}/view/#{full_seed_druid}"
    content_type_element = find_table_cell_following(header_text: 'Content type')
    expect(content_type_element.text).to eq('webarchive-seed')

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    expect(page).to have_link('thumbnail.jp2')
    expect(page).to have_content('image/jp2')
    expect(page).to have_content('400 px')

    # Verify that the purl XML includes the proper archived website URL
    expect_seed_url_in_public_xml(full_seed_druid, archived_url)
  end
end
