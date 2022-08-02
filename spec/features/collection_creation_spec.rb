# frozen_string_literal: true

RSpec.describe 'Use Argo to create a collection from APO page', type: :feature do
  let(:collection_title) { random_phrase }
  let(:collection_abstract) { 'Created by https://github.com/sul-dlss/infrastructure-integration-test' }
  let(:start_url) { "#{Settings.argo_url}/view/#{Settings.default_apo}" }

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'integration-testing')
  end

  scenario do
    click_link 'Create Collection'
    fill_in 'Collection Title', with: collection_title
    fill_in 'Collection Abstract', with: collection_abstract
    click_button 'Register Collection'

    expect(page).to have_content 'Created collection'

    collection_druid = find('.alert-info').text.split[2]
    visit "#{Settings.argo_url}/view/#{collection_druid}"

    expect(page).to have_content collection_title

    object_type_element = find_table_cell_following(header_text: 'Object type')
    expect(object_type_element.text).to eq('collection')

    apo_element = find_table_cell_following(header_text: 'Admin policy')
    expect(apo_element.first('a')[:href]).to end_with(Settings.default_apo)

    # wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)
  end
end
