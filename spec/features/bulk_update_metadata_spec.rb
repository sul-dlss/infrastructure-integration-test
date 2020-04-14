# frozen_string_literal: true

RSpec.describe 'Use Argo to upload metadata in a spreadsheet', type: :feature do
  let(:argo_home) { 'https://argo-stage.stanford.edu/' }
  let(:start_url) { "#{argo_home}view/druid:qc410yz8746" }
  let(:druid1_url) { "#{argo_home}view/fh141gk9610" }
  let(:druid2_url) { "#{argo_home}view/mw605wr9855" }
  let(:spec_location) { 'spec/fixtures/filled_template.xlsx' }
  let(:temp_xlsx) { Tempfile.new(['filled', '.xlsx']) }
  let(:title1) { RandomWord.phrases.next }
  let(:title2) { RandomWord.phrases.next }
  let(:note) { RandomWord.phrases.next }

  before do
    filled_xlsx = RubyXL::Parser.parse(spec_location)
    sheet_one = filled_xlsx.worksheets[0]
    sheet_one[2][3].change_contents title1
    sheet_one[3][3].change_contents title2
    filled_xlsx.write(temp_xlsx)
    authenticate!(start_url: start_url, expected_text: 'integration-testing')
  end

  scenario do
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
    expect(page).to have_content('Bulk job for APO (druid:qc410yz8746) deleted.')

    # Open druids and tests for titles
    visit(druid1_url)
    expect(page).to have_content title1

    visit(druid2_url)
    expect(page).to have_content title2
  end
end
