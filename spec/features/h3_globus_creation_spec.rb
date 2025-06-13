# frozen_string_literal: true

RSpec.describe 'Use H3 to create a collection and an item object belonging to it with files from globus' do
  let(:collection_title) { random_phrase }
  let(:item_title) { "Globus Test Item for #{collection_title}" }
  let(:user_email) { "#{AuthenticationHelpers.username}@stanford.edu" }
  let(:filename) { 'vision_for_stanford.jpg' }

  before do
    authenticate!(start_url: "#{Settings.h3_url}/", expected_text: /Enter here/)
  end

  scenario do
    # Go to the dashboard
    click_link_or_button 'Enter here'

    # CREATE COLLECTION
    click_link_or_button 'Create a new collection'
    # Checks for specific content in create collection view
    expect(page).to have_text('Untitled collection')

    # basic collection information
    fill_in 'Collection name', with: collection_title
    fill_in 'Description', with: "H3 Integration tests for #{collection_title}"
    fill_in 'Contact email', with: user_email

    # Select license
    find('.nav-link', text: 'License').click
    select 'CC0-1.0', from: 'collection_license'

    find('.nav-link', text: 'Save your collection').click
    expect(page).to have_text('Save your collection')
    click_link_or_button 'Save', class: 'btn-primary'

    expect(page).to have_css('h1', text: collection_title)
    collection_druid = page.current_url.split('/').last
    puts " *** h3 collection creation druid: #{collection_druid} ***" # useful for debugging

    # Create a Work in the collection
    visit "#{Settings.h3_url}/dashboard"

    click_link('Deposit to this collection', href: "/works/new?collection_druid=#{collection_druid.sub(':', '%3A')}")

    click_link_or_button 'Use Globus to transfer files'
    click_link_or_button 'Your computer' # Tell the H3 UI we will upload a file via the Globus UI

    page.within_window(page.windows.last) do
      # Now in the Globus UI, which should have opened in a new window, choose Stanford
      find_by_id('identity_provider-selectized').click
      find('.selectize-dropdown .option', text: 'Stanford University').click
      click_link_or_button 'Continue'
      # Now you need to auth again for Globus, yay!

      # the Globus upload button isn't ready until the "empty" text appears
      # but this means this folder needs to start as empty
      # which it should if the previous test run succeeded
      # and you aren't in the middle of using globus for H3 in stage/qa
      expect(page).to have_text('This folder is empty.')
      # select upload button
      find('span', text: 'Upload').click

      # Attaching file directly to the upload-files input
      attach_file('upload-files', "spec/fixtures/#{filename}", make_visible: true)

      # wait for the upload to be complete: the directory list should refresh when done and show the filename
      within('.directory-content') do
        expect(page).to have_content(filename)
      end
    end

    # Back in the H3 window, tell it we are done
    click_link_or_button 'Globus file transfer complete'

    # filename is on the H3 page
    expect(page).to have_text(filename)

    click_link_or_button 'Next'
    fill_in 'Title of deposit', with: item_title
    fill_in 'Contact email', with: user_email

    # Click Next to go to contributors tab
    click_link_or_button('Next')
    expect(page).to have_css('.nav-link.active', text: 'Authors / Contributors')
    expect(page).to have_css('.h4', text: 'Authors / Contributors')

    # Enter a contributor
    find('label', text: 'Individual').click
    within('.orcid-section') do
      find('label', text: 'Enter name manually').click
    end
    fill_in 'First name', with: 'Fox'
    fill_in 'Last name', with: 'Mulder'

    click_link_or_button 'Next'
    fill_in 'Abstract', with: "An abstract for #{collection_title} logo"
    fill_in 'Keywords (one per box)', with: 'Integration test'

    click_link_or_button 'Next'
    # Selects image type
    choose 'Image'

    find('.nav-link', text: 'Deposit', exact_text: true).click
    expect(page).to have_text('Submit your deposit')

    # if you have ever agreed to the terms, there will be no checkbox
    check('I agree to the SDR Terms of Deposit') if page.has_css?('#work_agree_to_terms', visible: true)
    click_link_or_button 'Deposit', class: 'btn-primary', exact_text: true

    # Checks if title is on resulting display
    expect(page).to have_css('h1', text: item_title)
    reload_page_until_timeout!(text: 'Deposited')

    work_druid = page.current_url.split('/').last
    puts " *** h3 work creation druid: #{work_druid} ***" # useful for debugging

    # Opens Argo detail page
    visit Settings.argo_url
    expect(page).to have_text('Welcome to Argo!')

    visit "#{Settings.argo_url}/view/#{work_druid}"
    reload_page_until_timeout!(text: 'v1 Accessioned')
    expect(page).to have_text(filename) # file made it from globus!

    # check PURL
    expect_text_on_purl_page(druid: work_druid, text: item_title)
  end
end
