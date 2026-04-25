# frozen_string_literal: true

# Integration: Argo, DSA
RSpec.describe 'Use Argo to register a collection', type: :registration do
  let(:collection_title) { random_phrase }
  let(:collection_abstract) { 'Created by https://github.com/sul-dlss/infrastructure-integration-test' }
  let(:start_url) { "#{Settings.argo_url}/view/#{Settings.default_apo}" }

  before do
    authenticate!(start_url:,
                  expected_text: 'integration-testing')
  end

  scenario do
    click_link_or_button 'Create Collection'
    fill_in 'Collection Title', with: collection_title
    fill_in 'Collection Abstract', with: collection_abstract
    click_link_or_button 'Register Collection'

    expect(page).to have_text 'Created collection'

    collection_druid = find('.alert-info').text.split[2]
    puts " *** collection creation druid: #{collection_druid} ***" # useful for debugging
    save_test_data(spec_name: 'collection_registration', data: { 'druid' => collection_druid, 'title' => collection_title })
  end
end
