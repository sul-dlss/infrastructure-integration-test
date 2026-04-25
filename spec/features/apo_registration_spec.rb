# frozen_string_literal: true

RSpec.describe 'Use Argo to register an APO', type: :registration do
  let(:apo_title) { "ZZZ Create APO test #{random_phrase}" }
  let(:start_url) { "#{Settings.argo_url}/apo/new" }
  let(:rights) { 'Stanford' }
  let(:terms_of_use) { 'Some oddly specific terms of use.' }
  let(:copyright) { 'You may not do anything with my stuff.' }
  let(:license) { 'Attribution Non-Commercial 3.0 Unported' }

  before do
    expected_text = 'The following defaults will apply to all newly registered objects.'
    authenticate!(start_url:, expected_text:)
  end

  scenario do
    fill_in 'Title', with: apo_title
    select rights, from: 'View access'
    select rights, from: 'Download access'
    select license, from: 'Default use license'
    fill_in 'Default Use and Reproduction statement', with: terms_of_use
    fill_in 'Default Copyright statement', with: copyright
    click_link_or_button 'Register APO'

    # make sure we're on an APO show view
    expect(page).to have_text apo_title
    # make sure APO is registered
    apo_druid = find_table_cell_following(header_text: 'DRUID').text
    expect(page).to have_text "APO #{apo_druid} created."
    save_test_data(spec_name: 'apo_creation', data: { 'druid' => apo_druid, 'title' => apo_title })
  end
end
