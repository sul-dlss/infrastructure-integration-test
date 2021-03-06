# frozen_string_literal: true

RSpec.describe 'Use Argo to create a collection from APO page', type: :feature do
  let(:collection_title) { RandomWord.phrases.next }
  let(:collection_abstract) { 'Created by https://github.com/sul-dlss/infrastructure-integration-test' }
  let(:start_url) { "#{Settings.argo_url}/view/#{Settings.default_apo}" }

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'integration-testing')
  end

  scenario do
    click_link 'Create Collection'

    within('#blacklight-modal') do
      fill_in 'Collection Title', with: collection_title
      fill_in 'Collection Abstract', with: collection_abstract
      click_button 'Register Collection'
    end

    expect(page).to have_content 'Created collection'

    collection_druid = find('.alert-info').text.split[2]
    visit "#{Settings.argo_url}/view/#{collection_druid}"

    expect(page).to have_content collection_title

    object_type_element = find('dd.blacklight-objecttype_ssim')
    expect(object_type_element.text).to eq('collection')

    apo_element = first('dd.blacklight-is_governed_by_ssim > a')
    expect(apo_element[:href]).to end_with(Settings.default_apo)

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)
  end
end
