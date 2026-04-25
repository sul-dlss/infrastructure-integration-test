# frozen_string_literal: true

# Integration: Argo, Modsulator, DSA
RSpec.describe 'Use Argo to update metadata in a spreadsheet (using modsulator)', type: :accessioning do
  let(:titles) { [random_phrase, random_phrase] }
  let(:note) { random_phrase }
  let(:start_url) { "#{Settings.argo_url}/view/#{Settings.default_apo}" }
  let(:druids) { [create_druid, create_druid] }

  before do
    authenticate!(start_url:, expected_text: 'integration-testing')
    save_test_data(spec_name: 'argo_spreadsheet_update',
                   data: { 'druids' => druids, 'titles' => titles })
  end

  scenario do
    temp_xlsx = update_xlsx(druids.first, titles.first, druids.last, titles.last)
    visit start_url
    # Open the MODS bulk jobs
    click_link_or_button 'Upload MODS'
    expect(page).to have_text 'Spreadsheet bulk upload for APO'

    # Open the Submit new file modal
    click_link_or_button 'Submit new file ...'
    expect(page).to have_text 'Submit MODS descriptive metadata for bulk processing'

    # Attach spreadsheet fixture, select spreadsheet input, and add note
    attach_file('Select', temp_xlsx.path)
    choose 'Spreadsheet input; load into objects'
    fill_in '3. Note', with: note
    click_link_or_button 'Submit'
    expect(page).to have_text('Bulk processing started')

    reload_page_until_timeout!(text: note)

    # Delete job run
    row = page.find(:xpath, "//table//tr[td/text()='#{note}']")
    tds = row.all('td')
    tds[9].find('form > button').click
    # Confirm delete in the popup
    within('#confirm-delete-modal') do
      click_link_or_button 'Delete' # '#bulk-delete-confirm'
    end
    expect(page).to have_text "Bulk job for APO (#{Settings.default_apo}) deleted."
  end
end
