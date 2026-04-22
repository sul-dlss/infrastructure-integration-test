# frozen_string_literal: true

# Integration: Argo, Goobi, DSA, Purl
# NOTE: this spec will be skipped unless run on stage, since there is no goobi in QA
RSpec.describe 'Create and accession object via Goobi', if: $sdr_env == 'stage' do
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:goobi_project_name) { 'Integration Testing' } # this project must exist in Goobi stage
  let(:source_id_random_word) { "#{random_noun}-#{random_alpha}" }
  let(:source_id) { "goobi-integration-test:#{source_id_random_word}" }
  let(:label_random_words) { random_phrase }
  let(:object_label) { "goobi integration test #{label_random_words}" }
  let(:collection_name) { 'integration-testing' }
  # this APO must exist on argo-stage and have goobiWF workflow and integration-testing collection available
  let(:apo_name) { 'Goobi Testing APO' }
  # the "Accession_Content_Expedited" workflow must exist on goobi-stage
  let(:goobi_tag) { 'DPG : Workflow : Accession_Content_Expedited ' }
  let(:goobi_workflow) { 'goobiWF' }

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  after do
    clear_downloads
  end

  scenario do
    # register new object that will be sent to goobi
    select apo_name, from: 'Admin Policy'
    select collection_name, from: 'Collection'
    select 'image', from: 'Content Type'
    select goobi_workflow, from: 'Initial Workflow'
    fill_in 'Project Name', with: goobi_project_name
    fill_in 'Tags', with: goobi_tag

    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    druid = "druid:#{bare_object_druid}"
    puts " *** goobi accessioning druid: #{druid} ***" # useful for debugging

    # wait to be sure goobiWF has finished running and goobi has time to process the incoming object
    sleep 2

    # login to Goobi
    visit Settings.goobi.url
    expect(page).to have_css('h2', text: 'Login')
    fill_in 'login', with: Settings.goobi.username
    # NOTE: "passwort" is not a typo, it's a german app
    # there is no english label and this is the ID of the field
    fill_in 'passwort', with: Settings.goobi.password
    click_link_or_button 'Log in'

    # find the new object
    expect(page).to have_text('Home page')
    click_link_or_button 'My tasks'
    fill_in 'search', with: druid
    click_link_or_button 'Search'

    # upload the test image
    click_link_or_button 'Accept editing of this task'
    attach_file('fileInput', 'spec/fixtures/stanford-logo.tiff', make_visible: true)
    # when the image finishes uploading, the "Select files" input will re-appear
    #  and we can continue with the test
    expect(page).to have_text('Select files')
    within '#uploadform' do
      click_link_or_button 'Overview'
    end
    expect(page).to have_text('stanford-logo.tiff')
    click_link_or_button 'Finish the edition of this task'

    # wait for goobi to do some back-end processing of the uploaded image
    # and then find object again to continue processing
    sleep 2
    fill_in 'search', with: druid
    click_link_or_button 'Search'
    expect(page).to have_text 'Final QA Validation'

    # now send the object off to be accessioned (this will export from goobi)
    click_link_or_button 'Accept editing of this task'
    click_link_or_button 'Finish the edition of this task'

    save_test_data(spec_name: 'goobi_accessioning_spec', data: { 'druid' => druid, 'label' => object_label })
  end
end
