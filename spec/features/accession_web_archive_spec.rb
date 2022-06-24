# frozen_string_literal: true

RSpec.describe 'Use was-registrar-app, Argo, and pywb to ensure web archives are accessioning', type: :feature do
  let(:job_specific_directory) { start_time.to_i.to_s }
  let(:remote_path) do
    "#{Settings.was_registrar.username}@#{Settings.was_registrar.host}:#{Settings.was_registrar.jobs_directory}/" \
      "#{job_specific_directory}/"
  end
  let(:source_id) { "test:#{start_time.to_i}" }
  let(:start_time) { Time.now }
  let(:start_url) { "#{Settings.was_registrar.url}/registration_jobs/new" }
  let(:updated_warc) do
    Tempfile.new([job_specific_directory, '.warc']).tap do |file|
      original_warc = File.read(warc_path)
      updated_warc = original_warc.lines
                                  .map do |line|
        line.start_with?('WARC-Date') ? line.sub!(/^(WARC-Date: )\S+(\s+)/, "\1#{start_time.utc.iso8601(3)}\2") : line
      end.join
      file.write(updated_warc)
      file.close
    end
  end
  let(:warc_path) { 'spec/fixtures/data.warc' }

  before do
    `ssh #{Settings.was_registrar.username}@#{Settings.was_registrar.host} mkdir -p \
         #{Settings.was_registrar.jobs_directory}/#{job_specific_directory}`
    raise("unable to create job directory: #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    `scp #{updated_warc.path} #{remote_path}`
    raise("unable to scp #{updated_warc_path} to #{remote_path}: #{$CHILD_STATUS.inspect}") unless $CHILD_STATUS.success?

    authenticate!(start_url: start_url, expected_text: 'New one-time registration')
  end

  scenario do
    fill_in 'Job directory', with: job_specific_directory
    fill_in 'Collection Druid', with: Settings.default_collection
    fill_in 'Source ID', with: source_id
    click_button 'Create Registration job'

    expect(page).to have_content('Queueing one-time registration.')

    # wait for registration to complete
    reload_page_until_timeout!(text: 'success: Created', table: { 'Job directory' => job_specific_directory })

    item_druid = find(:table_row, { 'Job directory' => job_specific_directory }).text.split.last
    visit "#{Settings.argo_url}/view/#{item_druid}"

    expect(page).to have_content(job_specific_directory)

    content_type_element = find_table_cell_following(header_text: 'Content type')
    expect(content_type_element.text).to eq('webarchive-binary')

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    visit "#{Settings.was_playback_url}/was/#{start_time.strftime('%Y%m%d%H%M%S')}/" \
          'https://library.stanford.edu/department/digital-library-systems-and-services-dlss/about-us'
    expect(page).to have_content('About us | Stanford Libraries')
  end
end
