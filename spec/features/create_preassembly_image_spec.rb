# frozen_string_literal: true

# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on Settings.preassembly_host at Settings.preassembly_bundle_directory
RSpec.describe 'Create and reaccession object via Pre-assembly', type: :feature do
  druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)

  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:preassembly_bundle_dir) { Settings.preassembly_bundle_directory }
  let(:remote_manifest_location) { "preassembly@#{Settings.preassembly_host}:#{preassembly_bundle_dir}" }
  let(:local_manifest_location) { 'tmp/manifest.csv' }
  let(:preassembly_project_name) { "IntegrationTest-preassembly-image-#{RandomWord.nouns.next}" }
  let(:source_id_random_word) { "#{RandomWord.adjs.next}-#{RandomWord.nouns.next}" }
  let(:source_id) { "image-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { "#{RandomWord.adjs.next} #{RandomWord.nouns.next}" }
  let(:object_label) { "image integration test #{label_random_words}" }
  let(:preassembly_manifest_csv) do
    <<~CSV
      druid,object
      #{druid},content
    CSV
  end

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Register DOR Items')
  end

  after do
    clear_downloads
  end

  scenario do
    # register new object
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    select 'Image', from: 'Content Type'
    fill_in 'Project Name', with: 'Integration Test - Image via Preassembly'
    click_button 'Add Row'
    td_list = all('td.invalidDisplay')
    td_list[0].click
    fill_in '1_source_id', with: source_id
    td_list[1].click
    fill_in '1_label', with: object_label
    find_field('1_label').send_keys :enter
    click_button('Lock')
    click_button('Register')
    # wait for object to be registered
    find('td[aria-describedby=data_status][title=success]')
    druid = find('td[aria-describedby=data_druid]').text
    # puts druid # useful for debugging

    # create manifest.csv file and scp it to preassembly staging directory
    File.write(local_manifest_location, preassembly_manifest_csv)
    `scp #{local_manifest_location} #{remote_manifest_location}`
    unless $CHILD_STATUS.success?
      raise("unable to scp #{local_manifest_location} to #{remote_manifest_location} - got #{$CHILD_STATUS.inspect}")
    end

    visit Settings.preassembly_url
    expect(page).to have_selector('h3', text: 'Complete the form below')

    fill_in 'Project name', with: preassembly_project_name
    select 'Pre Assembly Run', from: 'Job type'
    select 'Simple Image', from: 'Content structure'
    fill_in 'Bundle dir', with: preassembly_bundle_dir

    click_button 'Submit'
    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    # go to job details page, download result
    first('td > a').click
    expect(page).to have_content preassembly_project_name

    # wait for preassembly background job to finish
    reload_page_until_timeout!(text: 'Download', as_link: true)

    click_link 'Download'
    wait_for_download
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    # ensure Image files are all there, per pre-assembly, organized into specified resources
    visit "#{Settings.argo_url}/view/#{druid}"
    reload_page_until_timeout!(text: 'Resource (1) image')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Image 1')
    files = all('li.file')
    expect(files.size).to eq 2
    expect(files.first.text).to match(%r{(File image.jpg)\s\((image/jpeg, 28.)\d( KB, preserve)\)})
    expect(files.last.text).to match(%r{(File image.jp2)\s\((image/jp2, 64.)\d( KB, publish/shelve)\)})

    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    expect(page).to have_selector('.blacklight-content_type_ssim', text: 'image') # filled in by accessioning

    ### Re-accession

    # Get the original version from the page
    elem = find('dd.blacklight-status_ssi', text: 'Accessioned')
    md = /^v(\d+) Accessioned/.match(elem.text)
    version = md[1].to_i

    visit Settings.preassembly_url

    expect(page).to have_content 'Complete the form below'

    fill_in 'Project name', with: "#{RandomWord.adjs.next}-#{RandomWord.nouns.next}"
    select 'Pre Assembly Run', from: 'Job type'
    fill_in 'Bundle dir', with: preassembly_bundle_dir
    select 'Filename', from: 'Content metadata creation'

    click_button 'Submit'

    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    first('td > a').click # Click to the job details page

    reload_page_until_timeout!(text: 'Download', as_link: true)

    click_link 'Download'

    wait_for_download

    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    visit "#{Settings.argo_url}/view/druid:#{yaml[:pid]}"

    reload_page_until_timeout!(text: "v#{version + 1} Accessioned", with_reindex: true)
  end
end
