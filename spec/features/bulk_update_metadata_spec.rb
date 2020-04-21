# frozen_string_literal: true

RSpec.describe 'Use Argo to upload metadata in a spreadsheet', type: :feature do
  let(:argo_home) { 'https://argo-stage.stanford.edu/' }
  let(:start_url) { "#{argo_home}items/register" }
  let(:title1) { RandomWord.phrases.next }
  let(:title2) { RandomWord.phrases.next }
  let(:note) { RandomWord.phrases.next }

  before do
    authenticate!(start_url: start_url, expected_text: 'Register DOR Items')
  end

  scenario do
    druid1 = create_druid
    visit start_url
    druid2 = create_druid
    temp_xlsx = update_xlsx(druid1, title1, druid2, title2)

    visit("#{argo_home}view/#{APO}")
    # Opens the MODS bulk jobs
    click_link 'MODS bulk loads'
    expect(page).to have_content 'Datastream spreadsheet bulk upload for APO'

    # Opens the Submit new file modal
    click_link 'Submit new file ...'
    expect(page).to have_content 'Submit MODS descriptive metadata for bulk processing'

    # Attaches spreadsheet fixture, selects spreadsheet input, and adds note
    find('input#spreadsheet_file').attach_file(temp_xlsx.path)
    find('input#filetypes_1').click
    find('input#note_text').fill_in(with: note)
    click_button 'Submit'

    # Checks if job's note is on page
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?(note)
      end
    end

    # Delete's job run
    job_rows = page.find_all('div#bulk-upload-table > table > tbody > tr')
    job_rows.drop(1).each do |row|
      tds = row.find_all('td')
      next unless tds[3].text == note

      tds[9].find('form > button').click
      click_link 'Delete'
      break
    end
    expect(page).to have_content "Bulk job for APO (#{APO}) deleted."

    # Open druids and tests for titles
    visit("#{argo_home}view/#{druid1}")
    expect(page).to have_content title1

    visit("#{argo_home}view/#{druid2}")
    expect(page).to have_content title2
  end
end
