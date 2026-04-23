# frozen_string_literal: true

# Integration: Argo, Modsulator, DSA
RSpec.describe 'Use Argo to update metadata in a spreadsheet (using modsulator)' do
  let(:druid1) { test_data[:druid1] }
  let(:druid2) { test_data[:druid2] }
  let(:title1) { test_data[:title1] }
  let(:title2) { test_data[:title2] }
  let(:start_url) { "#{Settings.argo_url}/view/#{Settings.default_apo}" }
  let(:test_data) { load_test_data(spec_name: 'argo_spreadsheet_update') }

  before do
    authenticate!(start_url:, expected_text: 'integration-testing')
  end

  scenario do
    # Open druids and tests for titles
    puts "Checking that #{druid1} has title '#{title1}'..."
    visit "#{Settings.argo_url}/view/#{druid1}"
    reload_page_until_timeout!(text: title1)

    puts "Checking that #{druid2} has title '#{title2}'..."
    visit "#{Settings.argo_url}/view/#{druid2}"
    reload_page_until_timeout!(text: title2)
  end
end
