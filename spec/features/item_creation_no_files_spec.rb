# frozen_string_literal: true

RSpec.describe 'Use Argo to create an item object without any files' do
  let(:random_word) { random_phrase }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:source_id) { "create-obj-no-files-test:#{random_alpha}" }
  let(:user_tag) { 'Some : UniqueTagValue' }
  let(:project) { 'Awesome Project' }

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  scenario do
    # fill in registration form
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    select 'book', from: 'Content Type'
    fill_in 'Tag', with: user_tag
    fill_in 'Project Name', with: project

    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    object_druid = "druid:#{bare_object_druid}"
    puts " *** create object no files druid: #{object_druid} ***" # useful for debugging

    visit "#{Settings.argo_url}/view/#{object_druid}"

    # wait for registrationWF to finish
    reload_page_until_timeout!(text: 'v1 Registered')

    # add accessionWF
    click_link 'Add workflow'
    select 'accessionWF', from: 'wf'
    click_button 'Add'
    expect(page).to have_text('Added accessionWF')

    # look for tags
    expect(page).to have_text(user_tag)
    expect(page).to have_text("Project : #{project}")
    expect(page).to have_text("Registered By : #{AuthenticationHelpers.username}")

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    # open a new version
    click_link 'Unlock to make changes to this object'
    within '.modal-dialog' do
      select 'Admin', from: 'Type'
      fill_in 'Version description', with: 'opening version for integration testing'
      click_button 'Open Version'
    end
    # look for version text in History section
    expect(page).to have_text('opening version for integration testing')

    # close version
    click_link 'Close Version'
    within '.modal-dialog' do
      fill_in 'Version description', with: 'closing version for integration testing'
      click_button 'Close Version'
    end
    expect(page).to have_text('closing version for integration testing')
    page.refresh # solves problem of close version modal re-appearing

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v2 Accessioned')
  end
end
