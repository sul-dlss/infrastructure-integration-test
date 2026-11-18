# frozen_string_literal: true

# Integration: Argo, Modsulator, DSA
RSpec.describe 'Verify objects updated using a spreadsheet', type: :verify do
  let(:first_druid) { test_data[:druids].first }
  let(:second_druid) { test_data[:druids].last }
  let(:first_title) { test_data[:titles].first }
  let(:second_title) { test_data[:titles].last }
  let(:start_url) { "#{Settings.argo_url}/view/#{Settings.default_apo}" }
  let(:test_data) { load_test_data(spec_name: 'argo_spreadsheet_update') }

  before do
    authenticate!(start_url:, expected_text: 'integration-testing')
  end

  scenario do
    # Open druids and tests for titles
    puts "Checking that #{first_druid} has title '#{first_title}'..."
    visit "#{Settings.argo_url}/view/#{first_druid}"
    expect(page).to have_text(first_title)

    puts "Checking that #{second_druid} has title '#{second_title}'..."
    visit "#{Settings.argo_url}/view/#{second_druid}"
    expect(page).to have_text(second_title)
  end
end
