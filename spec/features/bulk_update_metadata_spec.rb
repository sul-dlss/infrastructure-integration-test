# frozen_string_literal: true
require 'rubyXL'
require 'rubyXL/convenience_methods/cell'

RSpec.describe 'Use Argo to upload metadata in a spreadsheet', type: :feature do
  let(:argo_home) { 'https://argo-stage.stanford.edu/' }
  let(:start_url) { "#{argo_home}view/druid:qc410yz8746" }
  let(:druid1_url) { "#{argo_home}view/fh141gk9610" }
  let(:druid2_url) { "#{argo_home}view/mw605wr9855" }
  let(:spec_location) { 'spec/fixtures/filled_template.xlsx' }
  let(:title1) { RandomWord.phrases.next }
  let(:title2) { RandomWord.phrases.next }
  let(:note) { RandomWord.phrases.next }


  before do
    filled_xlsx = RubyXL::Parser.parse(spec_location)
    sheet_1 = filled_xlsx.worksheets[0]
    sheet_1[2][3].change_contents title1
    sheet_1[3][3].change_contents title2
    filled_xlsx.write(spec_location)
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

    # Delete's job run
    byebug

    # Open druids and tests for titles

  end

  after do
    system "git checkout #{spec_location}"
  end
end
