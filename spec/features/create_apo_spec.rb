# frozen_string_literal: true

require 'io/console'
require 'random_word'

RSpec.describe 'Use Argo to create an administrative policy object', type: :feature do
  let(:apo_title) { RandomWord.phrases.next }
  let(:start_url) { 'https://argo-stage.stanford.edu/' }

  before do
    authenticate!(start_url: start_url, expected_text: 'Welcome to Argo!')
  end

  scenario do
    # Activate the dropdown
    click_link 'Register'
    click_link 'Register APO'

    expect(page).to have_content 'The following defaults will apply to all newly registered objects.'

    fill_in 'Title', with: apo_title
    # TODO: More APO set-up steps
    click_button 'Register APO'

    # Make sure we're on an APO show view
    expect(page).to have_content apo_title
    apo_druid = find('dd.blacklight-id').text
    expect(page).to have_content "APO #{apo_druid} created."
    object_type_element = find('dd.blacklight-objecttype_ssim')
    expect(object_type_element.text).to eq('adminPolicy')

    # Wait for workflows to finish
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?('v1 Accessioned')
      end
    end
  end
end
