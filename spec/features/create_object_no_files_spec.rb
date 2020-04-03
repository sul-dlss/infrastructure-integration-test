# frozen_string_literal: true

RSpec.describe 'Use Argo to create an object without any files', type: :feature do
  let(:random_word) { RandomWord.phrases.next }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:start_url) { 'https://argo-stage.stanford.edu/items/register' }
  let(:source_id) { "create-obj-no-files-test:#{random_word}" }

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Register DOR Items')
  end

  scenario do
    # fill in registration form
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    click_button 'Add Row'
    td_list = all('td.invalidDisplay')
    td_list[0].click
    fill_in '1_source_id', with: source_id
    td_list[1].click
    fill_in '1_label', with: object_label
    find_field('1_label').send_keys :enter

    click_button('Register')
    # wait for object to be registered
    find('td[aria-describedby=data_status][title=success]')
    object_druid = find('td[aria-describedby=data_druid]').text
    # puts "object_druid: #{object_druid}" # useful for debugging

    visit "https://argo-stage.stanford.edu/view/#{object_druid}"

    # wait for registrationWF to finish
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?('v1 Registered')
      end
    end

    # add accessionWF
    find_link('Add workflow').click
    page.select 'accessionWF', from: 'wf'
    find_button('Add').click

    # wait for accessioningWF to finish
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?('v1 Accessioned')
      end
    end
  end
end
