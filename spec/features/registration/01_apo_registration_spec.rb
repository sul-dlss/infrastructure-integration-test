# frozen_string_literal: true

RSpec.describe 'Use Argo to register an APO', :sample_accession, type: :registration do
  let(:apo_title) { "Integration Testing APO #{random_phrase}" }
  let(:start_url) { "#{Settings.argo_url}/apo/new" }
  let(:rights) { 'World' }
  let(:terms_of_use) { 'Use statement from APO' }
  let(:copyright) { 'None' }
  let(:license) { 'CC Attribution Non-Commercial 3.0 Unported' }

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

    # wait for accessionWF to finish and verify APO creation and move on
    reload_page_until_timeout!(text: 'v1 Accessioned')

    # Save the druid and title of the new APO to use in tests
    save_test_data(spec_name: 'apo_creation', data: { 'druid' => apo_druid, 'title' => apo_title })
  end
end
