# frozen_string_literal: true

RSpec.describe 'Use Argo to create an APO and verify new objects inherit its rights', type: :feature do
  let(:apo_title) { random_phrase }
  let(:start_url) { "#{Settings.argo_url}/apo/new" }
  let(:object_label) { "Object Label for APO #{apo_title}" }
  let(:source_id) { "apo-rights-test:#{apo_title}" }
  let(:rights) { 'Stanford' }
  let(:terms_of_use) { 'Some oddly specific terms of use.' }
  let(:copyright) { 'You may not do anything with my stuff.' }
  let(:license) { 'Attribution Non-Commercial 3.0 Unported' }

  before do
    expected_txt = 'The following defaults will apply to all newly registered objects.'
    authenticate!(start_url: start_url, expected_text: expected_txt)
  end

  scenario do
    fill_in 'Title', with: apo_title
    select rights, from: 'View access'
    select rights, from: 'Download access'
    select license, from: 'Default use license'
    fill_in 'Default Use and Reproduction statement', with: terms_of_use
    fill_in 'Default Copyright statement', with: copyright
    click_button 'Register APO'

    # make sure we're on an APO show view
    expect(page).to have_content apo_title
    # make sure APO is registered
    apo_druid = find_table_cell_following(header_text: 'DRUID').text
    expect(page).to have_content "APO #{apo_druid} created."

    # wait for accessioningWF to finish
    # Without this page.refresh, selenium webdriver complained:
    #  Element <a class="btn button btn-primary " href="/dor/reindex/druid:bc123df4567"> could not be scrolled into view
    # Explicitly trying to scroll up via "page.execute_script 'window.scrollTo(0,0);'" did not seem to work.
    page.refresh
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)

    # now register an object with this apo and verify default rights
    visit "#{Settings.argo_url}/registration"
    # fill in registration form
    select apo_title, from: 'Admin Policy'

    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    object_druid = "druid:#{bare_object_druid}"
    # puts "object_druid: #{object_druid}" # useful for debugging

    visit "#{Settings.argo_url}/view/#{object_druid}"

    # wait for registrationWF to finish and verify default access rights
    reload_page_until_timeout!(text: 'v1 Registered', with_reindex: true)
    expect(find_table_cell_following(header_text: 'Access rights').text).to eq("View: #{rights}, Download: #{rights}")

    expect(page).to have_content(terms_of_use)
    expect(page).to have_content(copyright)
    expect(page).to have_content(license)
  end
end
