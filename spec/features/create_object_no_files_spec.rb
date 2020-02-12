# frozen_string_literal: true
require 'io/console'
require 'random_word'

RSpec.describe 'Use Argo to create an object without any files', type: :feature do
  let(:random_word) { RandomWord.phrases.next }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:start_url) { 'https://argo-stage.stanford.edu/' }
  let(:source_id) { "test123:#{random_word}" }

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Welcome to Argo!')
  end

  scenario do
    # Click on the Register drop-down
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
        break if page.has_text?("v1 Registered")
      end
    end

   # Finds Druid and loads object's view
   object_druid = find('dd.blacklight-id').text
   visit "https://argo-stage.stanford.edu/view/#{object_druid}"

   # Opens Add workflow modal and starts accessionWF
   find_link('Add workflow').click
   page.select 'accessionWF', from: 'wf'
   find_button('Add').click

   # Wait for workflows to finish
   Timeout.timeout(100) do
     loop do
       page.evaluate_script("window.location.reload()")
       break if page.has_text?("v1 Accessioned")
     end
   end

  end
end
