# frozen_string_literal: true

RSpec.describe 'Use Argo to create an item object without any files and no collection' do
  let(:random_word) { random_phrase }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:source_id) { "create-obj-no-files-test:#{random_alpha}" }
  let(:user_tag) { 'Some : UniqueTagValue' }
  let(:project) { 'Awesome Project' }

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  scenario do
    # fill in registration form
    select 'integration-testing', from: 'Admin Policy'
    # Leaving collection unselected
    select 'book', from: 'Content Type'
    fill_in 'Tag', with: user_tag
    fill_in 'Project Name', with: project

    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    # This part of the registration form is in a turbo frame. The form can be
    # submitted before this frame has been loaded, which causes an HTTP 500
    # error. So make sure the page is fully loaded before submitting the form.
    expect(page).to have_text('Initial Workflow')
    sleep 1

    click_link_or_button 'Register', class: 'btn-primary', exact_text: true

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    object_druid = "druid:#{bare_object_druid}"
    puts " *** create object no files druid: #{object_druid} ***" # useful for debugging

    visit "#{Settings.argo_url}/view/#{object_druid}"

    # wait for registrationWF to finish
    reload_page_until_timeout!(text: 'v1 Registered')

    # add accessionWF
    click_link_or_button 'Close Version'
    within '.modal-dialog' do
      fill_in 'Version description', with: 'closing version for integration testing'
      click_link_or_button 'Close Version'
    end

    # look for tags
    expect(page).to have_text(user_tag)
    expect(page).to have_text("Project : #{project}")
    expect(page).to have_text("Registered By : #{AuthenticationHelpers.username}")

    # check no collection
    expect(page).to have_text('None selected')

    # wait for accessioningWF to finish; retry if Version mismatch on sdr-ingest-transfer
    reload_page_until_timeout_with_wf_step_retry!(expected_text: 'v1 Accessioned',
                                                  workflow: 'accessionWF',
                                                  workflow_retry_text: 'Version mismatch',
                                                  retry_wait: 2)

    # open a new version
    click_link_or_button 'Unlock to make changes to this object'
    within '.modal-dialog' do
      fill_in 'Version description', with: 'opening version for integration testing'
      click_link_or_button 'Open Version'
    end
    # look for version text in History section
    expect(page).to have_text('opening version for integration testing')

    # Change collection
    click_link_or_button 'Edit collections'
    within '.modal-dialog' do
      select 'integration-testing', from: 'collection'
      click_link_or_button 'Add Collection'
      click_link_or_button 'Cancel'
    end
    expect(page).to have_text('integration-testing')

    # close version
    click_link_or_button 'Close Version'
    within '.modal-dialog' do
      fill_in 'Version description', with: 'closing version for integration testing'
      click_link_or_button 'Close Version'
    end
    expect(page).to have_text('closing version for integration testing')
    page.refresh # solves problem of close version modal re-appearing

    # wait for accessioningWF to finish; retry if Version mismatch on sdr-ingest-transfer
    reload_page_until_timeout_with_wf_step_retry!(expected_text: 'v2 Accessioned',
                                                  workflow: nil,
                                                  retry_wait: 2) do |page|
      sleep 1
      if page.has_text?('v2 Accessioned')
        next true # done retrying, success
      elsif page.has_text?('Version mismatch', wait: 1)
        next 'accessionWF' # this message is for accessionWF steps
      elsif page.has_text?(/transfer-object : Error transferring bag .* for druid:/, wait: 1)
        next 'preservationIngestWF' # this message is for a preservationIngestWF step
      else
        next false # unexpected error message, will keep retrying with the last retried workflow
      end
    end
  end
end
