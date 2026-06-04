# frozen_string_literal: true

# Integration: Argo, DSA
RSpec.describe 'Use Argo to create a collection', type: :verify do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:druid) { test_data[:druid] }
  let(:title) { test_data[:title] }
  let(:test_data) { load_test_data(spec_name: 'collection_registration') }
  let(:apo_druid) { test_apo[:druid] }
  let(:test_apo) { load_test_data(spec_name: 'apo_creation') }

  before do
    authenticate!(start_url:, expected_text: title)
  end

  scenario do
    expect(page).to have_text title
    expect(page).to have_text 'v1 Accessioned'

    object_type_element = find_table_cell_following(header_text: 'Object type')
    expect(object_type_element.text).to eq('collection')

    apo_element = find_table_cell_following(header_text: 'Admin policy')
    expect(apo_element.first('a')[:href]).to end_with(apo_druid)
  end
end
