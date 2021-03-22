# frozen_string_literal: true

RSpec.describe "Use Argo to create an APO and verify new objects inherit it's rights", type: :feature do
  let(:apo_title) { RandomWord.phrases.next }
  let(:start_url) { "#{Settings.argo_url}/apo/new" }
  let(:object_label) { "Object Label for APO #{apo_title}" }
  let(:source_id) { "apo-rights-test:#{apo_title}" }
  let(:rights) { 'Stanford' }
  let(:terms_of_use) { 'Some oddly specific terms of use.' }
  let(:copyright) { 'You may not do anything with my stuff.' }
  let(:license) { 'Attribution Non-Commercial 3.0 Unported' }
  let(:license_uri) { 'https://creativecommons.org/licenses/by-nc/3.0/' }

  before do
    expected_txt = 'The following defaults will apply to all newly registered objects.'
    authenticate!(start_url: start_url, expected_text: expected_txt)
  end

  scenario do
    fill_in 'Title', with: apo_title
    select rights, from: 'default_object_rights'
    select license, from: 'use_license'
    fill_in 'use', with: terms_of_use
    fill_in 'copyright', with: copyright
    click_button 'Register APO'

    # make sure we're on an APO show view
    expect(page).to have_content apo_title
    # make sure APO is registered
    apo_druid = find('dd.blacklight-id').text
    expect(page).to have_content "APO #{apo_druid} created."
    object_type_element = find('dd.blacklight-objecttype_ssim')
    expect(object_type_element.text).to eq('adminPolicy')

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    # now register an object with this apo and verify default rights
    visit "#{Settings.argo_url}/registration"
    # fill in registration form
    select apo_title, from: 'Admin Policy'
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

    # wait for registrationWF to finish and verify default access rights
    reload_page_until_timeout!(text: 'v1 Registered', with_reindex: true)
    expect(page).to have_content "Access Rights:\n#{rights.downcase}"

    # these are in the cocina model data, which is hidden by default
    expect(page).to have_content(:all, terms_of_use)
    expect(page).to have_content(:all, copyright)
    expect(page).to have_content(:all, license_uri)
  end
end
