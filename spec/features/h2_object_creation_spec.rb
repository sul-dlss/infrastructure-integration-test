# frozen_string_literal: true

RSpec.describe 'Use H2 to create a collection and an item object belonging to it' do
  let(:collection_title) { random_phrase }
  let(:item_title) { "SUL Logo for #{collection_title}" }
  let(:user_email) { "#{AuthenticationHelpers.username}@stanford.edu" }

  before do
    authenticate!(start_url: "#{Settings.h2_url}/dashboard", expected_text: /Dashboard|Continue your deposit/)
  end

  # note! you likely want to use `click_deposit_and_handle_terms_modal` for deposit
  # form submission (instead of just `click_link_or_button 'Deposit'`), since the modal
  # may pop up on any attempt to deposit.
  scenario do
    # remove modal for deposit in progress, if present, waiting a bit for some rendering
    click_link_or_button 'No' if page.has_text?('Continue your deposit', wait: Settings.timeouts.post_authentication_text)

    # CREATE COLLECTION
    click_link_or_button '+ Create a new collection'
    # Checks for specific content in create collection view
    expect(page).to have_text('Manage release of deposits for discovery and download')

    # basic collection information
    fill_in 'Collection name', with: collection_title
    fill_in 'Description', with: "Integration tests for #{collection_title}"
    fill_in 'Contact email', with: user_email

    # set embargo for 6 months for collection members
    choose 'Delay release'

    # Select license
    select 'CC0-1.0', from: 'collection_required_license'

    # Adds user to depositor field
    click_link_or_button '+ Add another depositor'
    fill_in 'lookup SunetID', with: AuthenticationHelpers.username
    within '.participant-overlay' do
      click_link_or_button 'Add'
    end

    click_deposit_and_handle_terms_modal

    expect(page).to have_text(collection_title)
    expect(page).to have_text('+ Deposit to this collection')

    collection_id = page.current_url.split('/').last

    # RESERVE A PURL
    click_link_or_button 'Dashboard'
    within "#summary_collection_#{collection_id}" do
      click_link_or_button 'Reserve a PURL'
    end
    within '#purlReservationModal' do
      fill_in 'Enter a title for this deposit', with: item_title
      click_link_or_button 'Submit'
    end
    expect(page).to have_text(item_title)
    expect(page).to have_text('PURL Reserved') # async - it might take a bit

    # EDIT THE ITEM
    click_link_or_button "Choose Type and Edit #{item_title}"

    # Selects image type
    find('label', text: 'Image').click

    # Route to work deposit view
    click_link_or_button 'Continue'

    # Work Deposit view
    attach_file('spec/fixtures/sul-logo.png') do
      find_by_id('work_upload_type_browser').click
      find_button('Choose files').click
    end
    expect(page).to have_text('sul-logo.png')
    fill_in 'Title of deposit', with: item_title
    fill_in 'Contact email', with: user_email
    fill_in 'work_authors_attributes_0_first_name', with: 'Dana'
    fill_in 'work_authors_attributes_0_last_name', with: 'Scully'
    fill_in 'Abstract', with: "An abstract for #{collection_title} logo"
    fill_in 'Keyword', with: 'Integration test'

    # if you have previously agreed to the terms within the last year, there will be no checkbox
    check('I agree to the SDR Terms of Deposit') if page.has_css?('#work_agree_to_terms', wait: 0)

    find_button('Deposit').click

    expect(page).to have_text 'You have successfully deposited your work'
    click_link_or_button 'Return to dashboard'
    click_link_or_button item_title

    # Checks if title is on resulting display
    expect(page).to have_text(item_title)
    expect(page).to have_text(Settings.purl_url) # async - it might take a bit

    # Opens Argo and searches on title
    visit Settings.argo_url
    find_field('Search...').send_keys("\"#{item_title}\"", :enter)
    # Click on link with the item's title in the search results
    within '.document-title-heading' do
      click_link_or_button
    end
    sleep 1 # sometimes the current_url is not updated quickly enough
    bare_druid = page.current_url.split('druid:').last
    puts " *** h2 object creation druid: #{bare_druid} ***" # useful for debugging
    reload_page_until_timeout!(text: 'v1 Accessioned')

    # give preservation a chance to catch up before we create a new version
    #  since the shelving step does diffs that depend on files being visible in preservation
    sleep 5

    # create a new version
    visit "#{Settings.h2_url}/dashboard"
    click_link_or_button "Edit #{item_title}"
    fill_in 'What\'s changing?', with: 'abstract'
    fill_in 'Abstract', with: "A changed abstract for #{collection_title} logo"
    click_deposit_and_handle_terms_modal

    expect(page).to have_text 'You have successfully deposited your work'

    # Opens Argo detail page
    visit "#{Settings.argo_url}/view/#{bare_druid}"
    # wait for accessioningWF to finish; retry if error on shelving step, likely caused by a race condition
    reload_page_until_timeout_with_wf_step_retry!(expected_text: 'v2 Accessioned',
                                                  workflow: 'accessionWF',
                                                  workflow_retry_text: 'Error: shelve : problem with shelve',
                                                  retry_wait: 10)

    # check Argo facet field with 6 month embargo
    visit Settings.argo_url
    find_field('Search...').send_keys("\"#{item_title}\"", :enter)
    click_link_or_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      expect(page).to have_no_text('up to 7 days', wait: 0)
    end

    # Click on link with the item's title in the search results
    within '.document-title-heading' do
      click_link_or_button
    end
    # check embargo date
    embargo_date = DateTime.now.getutc.to_date >> 6
    expect(page).to have_text("Embargoed until #{embargo_date.to_formatted_s(:long)}")

    # check purl page for embargo
    expect_text_on_purl_page(
      druid: bare_druid,
      text: "Access is restricted until #{embargo_date.strftime('%d-%b-%Y')}",
      within_frame: true
    )

    # change embargo date
    new_embargo_date = Date.today + 3
    visit "#{Settings.argo_url}/view/#{bare_druid}"
    # open a new version so we can manage embargo
    click_link_or_button 'Unlock to make changes to this object'
    within '.modal-dialog' do
      fill_in 'Version description', with: 'opening version for integration testing'
      click_link_or_button 'Open Version'
    end
    click_link_or_button 'Manage embargo'
    within '#modal-frame' do
      fill_in('Enter the date when this embargo ends', with: new_embargo_date.strftime('%F'))
      click_link_or_button 'Save'
    end
    reload_page_until_timeout!(text: "Embargoed until #{new_embargo_date.to_formatted_s(:long)}")

    # check Argo facet field with 3 day embargo
    fill_in 'Search...', with: bare_druid
    click_button 'Search'
    reload_page_until_timeout!(text: 'Embargo Release Date')
    click_link_or_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      find_link('up to 7 days')
    end

    # republish the item to purl
    visit "#{Settings.argo_url}/view/#{bare_druid}"
    click_link_or_button 'Manage PURL'
    click_link_or_button 'Publish'

    # check purl page for 3 day embargo
    expect_text_on_purl_page(
      druid: bare_druid,
      text: "Access is restricted until #{new_embargo_date.strftime('%d-%b-%Y')}",
      within_frame: true
    )
  end
end
