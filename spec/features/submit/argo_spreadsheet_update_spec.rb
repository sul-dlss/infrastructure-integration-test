# frozen_string_literal: true

# Integration: Argo, Modsulator, DSA
RSpec.describe 'Use Argo to update metadata in a spreadsheet (using modsulator)' do
  let(:title1) { random_phrase } # rubocop:disable RSpec/IndexedLet
  let(:title2) { random_phrase } # rubocop:disable RSpec/IndexedLet
  let(:note) { random_phrase }
  let(:start_url) { "#{Settings.argo_url}/view/#{Settings.default_apo}" }
  let(:druid1) { create_druid }
  let(:druid2) { create_druid }

  before do
    authenticate!(start_url:, expected_text: 'integration-testing')
    save_test_data(spec_name: 'argo_spreadsheet_update', data: { 'druid1' => druid1, 'druid2' => druid2, 'title1' => title1, 'title2' => title2 })
  end

  scenario do
    temp_xlsx = update_xlsx(druid1, title1, druid2, title2)
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
