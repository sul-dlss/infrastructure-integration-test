# frozen_string_literal: true

# Integration: Argo, Goobi, DSA, Purl
# NOTE: this spec will be skipped unless run on stage, since there is no goobi in QA
RSpec.describe 'Create and accession object via Goobi', if: $sdr_env == 'stage', type: :accessioning do
  let(:druid) { test_data[:druid] }
  let(:title) { test_data[:title] }
  let(:test_data) { load_test_data(spec_name: 'goobi_accessing') }

  after do
    clear_downloads
  end

  scenario do
    # login to Goobi
    visit Settings.goobi.url
    expect(page).to have_css('h2', text: 'Login')
    fill_in 'login', with: Settings.goobi.username
    # NOTE: "passwort" is not a typo, it's a german app
    # there is no english label and this is the ID of the field
    fill_in 'passwort', with: Settings.goobi.password
    click_link_or_button 'Log in'

    # find the new object
    expect(page).to have_text('Home page')
    click_link_or_button 'My tasks'
    fill_in 'search', with: druid
    click_link_or_button 'Search'

    # upload the test image
    click_link_or_button 'Accept editing of this task'
    attach_file('fileInput', 'spec/fixtures/stanford-logo.tiff', make_visible: true)
    # when the image finishes uploading, the "Select files" input will re-appear
    #  and we can continue with the test
    expect(page).to have_text('Select files')
    within '#uploadform' do
      click_link_or_button 'Overview'
    end
    expect(page).to have_text('stanford-logo.tiff')
    click_link_or_button 'Finish the edition of this task'

    # wait for goobi to do some back-end processing of the uploaded image
    # and then find object again to continue processing
    sleep 2
    fill_in 'search', with: druid
    click_link_or_button 'Search'
    expect(page).to have_text 'Final QA Validation'

    # now send the object off to be accessioned (this will export from goobi)
    click_link_or_button 'Accept editing of this task'
    click_link_or_button 'Finish the edition of this task'
  end
end
