# frozen_string_literal: true

require 'io/console'
require 'jwt'
require 'random_word'

RSpec.describe 'TechMD Service Pre and Post Accessioning', type: :feature do
  let(:random_word) { RandomWord.phrases.next }
  let(:start_url) { 'https://argo-stage.stanford.edu/' }
  let(:api_url) { 'https://dor-techmd-stage.stanford.edu/' }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:source_id) { "testing:#{random_word}" }
  let(:jwt) { JWT.encode({ sub: 'tester' }, ENV.fetch('TECHMD_HMAC'), 'HS256') }

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Welcome to Argo!')
  end

  # rubocop:disable RSpec/ExampleLength
  it 'generates technical metadata for some files' do
    # Create a new object in Argo
    click_link 'Register'
    click_link 'Register Items'
    expect(page).to have_content 'Register DOR Items'

    # Add a row and fill source id and label fields
    click_button 'Add Row'

    # Click Source ID and Label to add input
    td_list = all('td.invalidDisplay')
    td_list[0].click
    fill_in '1_source_id', with: source_id

    td_list[1].click
    fill_in '1_label', with: object_label

    # Click on check-box to select row
    find('#jqg_data_0').click

    # Sends enter key to save
    find_field('1_label').send_keys :enter

    # Clicks on Register Button
    find_button('Register').click

    # Searches for source id
    Timeout.timeout(100) do
      loop do
        fill_in 'q', with: source_id
        find_button('search').click
        break if page.has_text?('v1 Registered')
      end
    end

    # Finds Druid and loads object's view
    object_druid = find('dd.blacklight-id').text

    puts "New druid is #{object_druid}"

    # Should return a 404 when querying technical-metadata server
    druid_techmd_url = "#{api_url}/v1/technical-metadata/druid/#{object_druid}"
    get_response = Faraday.get(druid_techmd_url,
                               {},
                               'Authorization': "Bearer #{jwt}")
    expect(get_response.status).to be(404)

    # Use SDR Client to add filestreams?

    # Run accessionWF on Druid

    # Check technical-metadata server for generated metadata on filestreams
  end
  # rubocop:enable RSpec/ExampleLength
end
