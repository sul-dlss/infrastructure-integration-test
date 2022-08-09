# frozen_string_literal: true

RSpec.describe 'Use Argo to update metadata in a spreadsheet (using modsulator)', type: :feature do
  let(:title1) { random_phrase }
  let(:title2) { random_phrase }
  let(:note) { random_phrase }

  before do
    authenticate!(start_url: Settings.argo_url, expected_text: 'Welcome to Argo!')
  end

  scenario do
    druid1 = create_druid
    druid2 = create_druid
    puts " *** bulk update metadata druids: #{druid1}, #{druid2} ***" # useful for debugging
    temp_xlsx = update_xlsx(druid1, title1, druid2, title2)

    visit "#{Settings.argo_url}/view/#{Settings.default_apo}"
    # Open the MODS bulk jobs
    click_link 'Upload MODS'
    expect(page).to have_content 'Spreadsheet bulk upload for APO'

    # Open the Submit new file modal
    click_link 'Submit new file ...'
    expect(page).to have_content 'Submit MODS descriptive metadata for bulk processing'

    # Attach spreadsheet fixture, select spreadsheet input, and add note
    attach_file('Select', temp_xlsx.path)
    choose 'Spreadsheet input; load into objects'
    fill_in '3. Note', with: note
    click_button 'Submit'
    expect(page).to have_content('Bulk processing started')

    reload_page_until_timeout!(text: note)

    # Delete job run
    row = page.find(:xpath, "//table//tr[td/text()='#{note}']")
    tds = row.all('td')
    tds[9].find('form > button').click
    # Confirm delete in the popup
    within('#confirm-delete-modal') do
      click_button 'Delete' # '#bulk-delete-confirm'
    end
    expect(page).to have_content "Bulk job for APO (#{Settings.default_apo}) deleted."

    # Open druids and tests for titles
    visit "#{Settings.argo_url}/view/#{druid1}"
    reload_page_until_timeout!(text: title1)

    visit "#{Settings.argo_url}/view/#{druid2}"
    reload_page_until_timeout!(text: title2)
  end
end
