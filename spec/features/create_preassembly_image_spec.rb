# frozen_string_literal: true

# Preassembly requires that files to be included in an object must be available on a mounted drive
# To this end, files have been placed on preassembly-stage at /dor/staging/integration-tests/image-test
RSpec.describe 'Create new image object via Pre-assembly', type: :feature do
  druid = '' # used for HEREDOC preassembly manifest files (can't be memoized)

  let(:start_url) { 'https://argo-stage.stanford.edu/items/register' }
  let(:preassembly_bundle_dir) { '/dor/staging/integration-tests/image-test' }
  let(:remote_manifest_location) { "preassembly@sul-preassembly-stage:#{preassembly_bundle_dir}" }
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

  it do
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

    visit 'https://sul-preassembly-stage.stanford.edu/'
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
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_link?('Download')
      end
    end
    click_link 'Download'
    wait_for_download
    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    # ensure audio object files are all there, per pre-assembly, organized into specified resources
    visit "https://argo-stage.stanford.edu/view/#{druid}"
    expect(page).to have_selector('#document-contents-section > .resource-list > li.resource', text: 'Resource (1) image')
    expect(page).to have_selector('#document-contents-section > .resource-list > li', text: 'Image 1')
    files = all('li.file')
    expect(files.size).to eq 2
    expect(files.first.text).to eq 'File image.jpg (image/jpeg, 28.9 KB, preserve)'
    expect(files.last.text). to eq 'File image.jp2 (image/jp2, 64.4 KB, publish/shelve)'

    # Wait for accessioningWF to finish
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?('v1 Accessioned')
      end
    end
    expect(page).to have_selector('.blacklight-content_type_ssim', text: 'image') # filled in by accessioning
  end
end
