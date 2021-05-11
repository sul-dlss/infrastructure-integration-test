# frozen_string_literal: true

RSpec.describe 'Use Argo to create an object without any files', type: :feature do
  let(:random_word) { RandomWord.phrases.next }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:source_id) { "create-obj-no-files-test:#{random_word}" }

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Register DOR Items')
  end

  scenario do
    # fill in registration form
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    click_button 'Add Row'
    td_list = all('td.invalidDisplay')
    td_list[0].click
    fill_in '1_source_id', with: source_id
    td_list[1].click
    fill_in '1_label', with: object_label
    find_field('1_label').send_keys :enter

    click_button('Register')
    # wait for object to be registered
    find('td[aria-describedby=data_status][title=success]')
    object_druid = find('td[aria-describedby=data_druid]').text
    # puts "object_druid: #{object_druid}" # useful for debugging

    visit "#{Settings.argo_url}/view/#{object_druid}"

    # wait for registrationWF to finish
    reload_page_until_timeout!(text: 'v1 Registered', with_reindex: true)

    # add accessionWF
    click_link 'Add workflow'
    select 'accessionWF', from: 'wf'
    click_button 'Add'
    expect(page).to have_text('Added accessionWF')

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    # open a new version
    click_link 'Open for modification'
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

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v2 Accessioned', with_reindex: true)
  end
end
