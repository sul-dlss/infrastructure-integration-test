# frozen_string_literal: true

RSpec.describe 'Use Argo to upload metadata in a spreadsheet', type: :feature do
  let(:start_url) { 'https://argo-stage.stanford.edu/view/druid:qc410yz8746' }
  let(:note) { RandomWord.phrases.next }

  before do
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
    find('input#spreadsheet_file').attach_file('spec/fixtures/filled_template.xlsx')
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
  end
end
