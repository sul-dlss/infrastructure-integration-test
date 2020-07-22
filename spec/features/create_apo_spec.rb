# frozen_string_literal: true

RSpec.describe 'Use Argo to create an administrative policy object', type: :feature do
  let(:apo_title) { RandomWord.phrases.next }
  let(:start_url) { "#{Settings.argo_url}/apo/new" }

  before do
    expected_txt = 'The following defaults will apply to all newly registered objects.'
    authenticate!(start_url: start_url, expected_text: expected_txt)
  end

  scenario do
    fill_in 'Title', with: apo_title
    # TODO: More APO set-up steps / form fields exercised
    click_button 'Register APO'

    # make sure we're on an APO show view
    expect(page).to have_content apo_title
    # make sure APO is registered
    apo_druid = find('dd.blacklight-id').text
    expect(page).to have_content "APO #{apo_druid} created."
    object_type_element = find('dd.blacklight-objecttype_ssim')
    expect(object_type_element.text).to eq('adminPolicy')

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')
  end
end
