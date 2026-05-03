# frozen_string_literal: true

# TODO-Aaron: Needs attention, this spec is still unreliable (on the register button click)
RSpec.describe 'Use Argo verify new objects inherit new APO rights', type: :accessioning do
  let(:apo_title) { test_data[:title] }
  let(:apo_druid) { test_data[:druid] }
  let(:test_data) { load_test_data(spec_name: 'apo_creation') }
  let(:start_url) { "#{Settings.argo_url}/view/#{apo_druid}" }
  let(:object_label) { "Object Label for APO #{apo_title}" }
  let(:source_id) { "apo-rights-test:#{SecureRandom.uuid}" }
  let(:rights) { 'Stanford' }
  let(:terms_of_use) { 'Some oddly specific terms of use.' }
  let(:copyright) { 'You may not do anything with my stuff.' }
  let(:license) { 'Attribution Non-Commercial 3.0 Unported' }

  before do
    authenticate!(start_url:, expected_text: apo_title)
  end

  scenario do
    expect(page).to have_text 'v1 Accessioned'

    # now register an object with this apo and verify default rights
    visit "#{Settings.argo_url}/registration"
    # fill in registration form
    select apo_title, from: 'Admin Policy'

    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    page.scroll_to(:bottom)

    sleep(2)
    click_button('Register')
    # button = find_button('Register')
    # execute_script('arguments[0].scrollIntoView(true)', button)
    # button.click

    sleep(2)
    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    object_druid = "druid:#{bare_object_druid}"
    puts " *** APO creation druid: #{object_druid} ***" # useful for debugging

    visit "#{Settings.argo_url}/view/#{object_druid}"

    # wait for registrationWF to finish and verify default access rights
    reload_page_until_timeout!(text: 'v1 Registered')
    expect(find_table_cell_following(header_text: 'Access rights').text).to eq("View: #{rights}, Download: #{rights}")

    expect(page).to have_text(terms_of_use)
    expect(page).to have_text(copyright)
    expect(page).to have_text(license)
  end
end
