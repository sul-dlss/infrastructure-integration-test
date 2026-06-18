# frozen_string_literal: true

# Integration: Argo, DSA
RSpec.describe 'Use Argo to create an item object without any files and no collection', type: :accessioning do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:druid) { test_data[:druid] }
  let(:expected_text) { test_data[:title] }
  let(:test_data) { load_test_data(spec_name: 'item_creation_no_files_or_collection') }
  let(:user_tag) { 'Some : UniqueTagValue' }
  let(:project) { 'Awesome Project' }

  before do
    authenticate!(start_url:, expected_text:)
  end

  scenario do
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

    ## Step 3: Wait for and verify accessioning
    # wait for accessioningWF to finish; retry if Version mismatch on sdr-ingest-transfer
    reload_page_until_timeout_with_wf_step_retry!(expected_text: 'v1 Accessioned',
                                                  workflow: 'accessionWF',
                                                  workflow_retry_text: 'Version mismatch',
                                                  retry_wait: 2)

    ## Step 4: Open a new version and verify
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

    ## Step 5: Wait for and verify accessioning
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
