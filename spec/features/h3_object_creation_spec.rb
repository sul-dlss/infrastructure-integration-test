# frozen_string_literal: true

RSpec.describe 'Use H3 to create a collection and an item object belonging to it' do
  let(:collection_title) { random_phrase }
  let(:item_title) { "SUL Logo for #{collection_title}" }
  let(:user_email) { "#{AuthenticationHelpers.username}@stanford.edu" }

  before do
    authenticate!(start_url: "#{Settings.h3_url}/", expected_text: /Enter here/)
  end

  scenario do
    # remove modal for deposit in progress, if present, waiting a bit for some rendering
    # click_link_or_button 'No' if page.has_text?('Continue your deposit', wait: Settings.timeouts.h2_terms_modal_wait)

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

    # set embargo for 6 months for collection members
    # choose 'Delay release'

    # Select license
    # select 'CC0-1.0', from: 'collection_required_license'

    # Adds user to depositor field
    # click_link_or_button '+ Add another depositor'
    # fill_in 'lookup SunetID', with: AuthenticationHelpers.username
    # within '.participant-overlay' do
    #   click_link_or_button 'Add'
    # end

    # click_deposit_and_handle_terms_modal
    find('.nav-link', text: 'Deposit', exact_text: true).click
    expect(page).to have_text('Submit your collection')
    click_link_or_button 'Deposit', class: 'btn-primary'

    # expect(page).to have_text('You have successfully deposited your collection')

    # Checks if title is on resulting display

    expect(page).to have_text(collection_title)
    #   expect(page).to have_text('+ Deposit to this collection')

    collection_druid = page.current_url.split('/').last
    puts " *** h3 collection creation druid: #{collection_druid} ***" # useful for debugging

    # Create a Work in the collection
    visit "#{Settings.h3_url}/dashboard"

    click_link('Deposit to this collection', href: "/works/new?collection_druid=#{collection_druid.sub(':', '%3A')}")

    #   # RESERVE A PURL
    #   click_link_or_button 'Dashboard'
    #   within "#summary_collection_#{collection_id}" do
    #     click_link_or_button 'Reserve a PURL'
    #   end
    #   within '#purlReservationModal' do
    #     fill_in 'Enter a title for this deposit', with: item_title
    #     click_link_or_button 'Submit'
    #   end
    #   expect(page).to have_text(item_title)
    #   expect(page).to have_text('PURL Reserved') # async - it might take a bit

    #   # EDIT THE ITEM
    #   click_link_or_button "Choose Type and Edit #{item_title}"

    #   # Selects image type
    #   find('label', text: 'Image').click

    #   # Route to work deposit view
    #   click_link_or_button 'Continue'

    #   # Work Deposit view
    find('.dropzone').drop('spec/fixtures/sul-logo.png')

    expect(page).to have_text('sul-logo.png')

    click_link_or_button 'Next'
    fill_in 'Title of deposit', with: item_title
    fill_in 'Contact email', with: user_email

    # Click Next to go to contributors tab
    click_link_or_button('Next')
    expect(page).to have_css('.nav-link.active', text: 'Contributors')
    expect(page).to have_css('.h4', text: 'Contributors')

    # Enter a contributor
    select('Creator', from: 'work_contributors_attributes_0_person_role')
    within('.orcid-section') do
      find('label', text: 'No').click
    end
    fill_in 'First name', with: 'Dana'
    fill_in 'Last name', with: 'Scully'

    click_link_or_button 'Next'
    fill_in 'Abstract', with: "An abstract for #{collection_title} logo"
    fill_in 'Keywords (one per box)', with: 'Integration test'

    click_link_or_button 'Next'
    # Selects image type
    choose 'Image'

    # find('.nav-link', text: 'License').click
    # select 'CC-BY-4.0 Attribution International', from: 'License'

    within('#main-container') do
      expect(page).to have_no_text('Terms of deposit')
    end

    find('.nav-link', text: 'Deposit', exact_text: true).click
    click_link_or_button 'Deposit', class: 'btn-primary'

    #   # if you have previously agreed to the terms within the last year, there will be no checkbox
    #   check('I agree to the SDR Terms of Deposit') if page.has_css?('#work_agree_to_terms', wait: 0)

    #   click_deposit_and_handle_terms_modal

    #   expect(page).to have_text 'You have successfully deposited your work'
    #   click_link_or_button 'Return to dashboard'
    #   click_link_or_button item_title

    # Checks if title is on resulting display
    expect(page).to have_text(item_title)
    reload_page_until_timeout!(text: 'Deposited')

    work_druid = page.current_url.split('/').last

    #   expect(page).to have_text(Settings.purl_url) # async - it might take a bit

    #   bare_druid = find('a.copy-button')[:href][-11, 11]
    puts " *** h3 work creation druid: #{work_druid} ***" # useful for debugging

    #   # Opens Argo detail page
    visit Settings.argo_url
    expect(page).to have_text('Welcome to Argo!')

    visit "#{Settings.argo_url}/view/#{work_druid}"
    #   puts " *** h2 object creation druid: #{bare_druid} ***" # useful for debugging
    expect(page).to have_text('v1 Accessioned')
    #   reload_page_until_timeout!(text: 'v1 Accessioned')

    # give preservation a chance to catch up before we create a new version
    #  since the shelving step does diffs that depend on files being visible in preservation
    # sleep 5

    # create a new version
    visit "#{Settings.h3_url}/dashboard"
    click_link_or_button item_title
    click_link_or_button 'Edit or deposit'
    find('.nav-link', text: 'Abstract & keywords').click
    #   click_link_or_button "Edit #{item_title}"
    #   choose('No') # Do you want to create a new version of this deposit?
    #   fill_in 'What\'s changing?', with: 'abstract'
    fill_in 'Abstract', with: "A changed abstract for #{collection_title} logo"
    #   click_deposit_and_handle_terms_modal

    #   expect(page).to have_text 'You have successfully deposited your work'
    find('.nav-link', text: 'Deposit').click
    click_link_or_button 'Deposit', class: 'btn-primary'

    expect(page).to have_text(item_title)
    reload_page_until_timeout!(text: 'Deposited')

    # Opens Argo detail page
    visit "#{Settings.argo_url}/view/#{work_druid}"
    # wait for accessioningWF to finish; retry if error on shelving step, likely caused by a race condition
    reload_page_until_timeout_with_wf_step_retry!(expected_text: 'v2 Accessioned',
                                                  workflow: 'accessionWF',
                                                  workflow_retry_text: 'Error: shelve : problem with shelve',
                                                  retry_wait: 10)

    #   # check Argo facet field with 6 month embargo
    #   visit Settings.argo_url
    #   find_field('Search...').send_keys("\"#{item_title}\"", :enter)
    #   click_link_or_button('Embargo Release Date')
    #   within '#facet-embargo_release_date ul.facet-values' do
    #     expect(page).to have_no_text('up to 7 days', wait: 0)
    #   end

    #   # Click on link with the item's title in the search results
    #   within '.document-title-heading' do
    #     click_link_or_button
    #   end
    #   # check embargo date
    #   embargo_date = DateTime.now.getutc.to_date >> 6
    #   expect(page).to have_text("Embargoed until #{embargo_date.to_formatted_s(:long)}")

    #   # check purl page for embargo
    #   expect_text_on_purl_page(
    #     druid: bare_druid,
    #     text: "Access is restricted until #{embargo_date.strftime('%d-%b-%Y')}",
    #     within_frame: true
    #   )

    #   # change embargo date
    #   new_embargo_date = Date.today + 3
    #   visit "#{Settings.argo_url}/view/#{bare_druid}"
    #   # open a new version so we can manage embargo
    #   click_link_or_button 'Unlock to make changes to this object'
    #   within '.modal-dialog' do
    #     fill_in 'Version description', with: 'opening version for integration testing'
    #     click_link_or_button 'Open Version'
    #   end
    #   click_link_or_button 'Manage embargo'
    #   within '#modal-frame' do
    #     fill_in('Enter the date when this embargo ends', with: new_embargo_date.strftime('%F'))
    #     click_link_or_button 'Save'
    #   end
    #   reload_page_until_timeout!(text: "Embargoed until #{new_embargo_date.to_formatted_s(:long)}")

    #   # check Argo facet field with 3 day embargo
    #   fill_in 'Search...', with: bare_druid
    #   click_button 'Search'
    #   reload_page_until_timeout!(text: 'Embargo Release Date')
    #   click_link_or_button('Embargo Release Date')
    #   within '#facet-embargo_release_date ul.facet-values' do
    #     find_link('up to 7 days')
    #   end

    #   # close version to republish the item to purl
    #   visit "#{Settings.argo_url}/view/#{bare_druid}"
    #   click_link_or_button 'Close Version'
    #   within '.modal-dialog' do
    #     fill_in 'Version description', with: 'closing version for integration testing'
    #     click_link_or_button 'Close Version'
    #   end
    #   expect(page).to have_text('closing version for integration testing')
    #   page.refresh # solves problem of close version modal re-appearing

    #   # check purl page for 3 day embargo
    #   expect_text_on_purl_page(
    #     druid: bare_druid,
    #     text: "Access is restricted until #{new_embargo_date.strftime('%d-%b-%Y')}",
    #     within_frame: true
    #   )
  end
end
