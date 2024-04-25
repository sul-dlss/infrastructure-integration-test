# frozen_string_literal: true

RSpec.describe 'Use H2 to create a collection and an item object belonging to it with files from globus' do
  # Including "Integration Test" in the title causes H2 to use the configured integration test
  # globus endpoint, which already has files.
  let(:collection_title) { "#{random_phrase} Integration Test" }
  let(:item_title) { "My Icon Collection for #{collection_title}" }
  let(:user_email) { "#{AuthenticationHelpers.username}@stanford.edu" }

  before do
    authenticate!(start_url: "#{Settings.h2_url}/dashboard", expected_text: /Dashboard|Continue your deposit/)
  end

  # note! you likely want to use `click_deposit_and_handle_terms_modal` for deposit
  # form submission (instead of just `click_link_or_button 'Deposit'`), since the modal
  # may pop up on any attempt to deposit.
  scenario do
    # remove modal for deposit in progress, if present, waiting a bit for some rendering
    click_link_or_button 'No' if page.has_text?('Continue your deposit', wait: Settings.timeouts.h2_terms_modal_wait)

    # CREATE COLLECTION
    click_link_or_button '+ Create a new collection'
    # Checks for specific content in create collection view
    expect(page).to have_text('Manage release of deposits for discovery and download')

    # basic collection information
    fill_in 'Collection name', with: collection_title
    fill_in 'Description', with: "Integration tests for #{collection_title}"
    fill_in 'Contact email', with: user_email

    # Select license
    select 'CC0-1.0', from: 'collection_required_license'

    click_deposit_and_handle_terms_modal
    expect(page).to have_text(collection_title)
    expect(page).to have_text('+ Deposit to this collection')

    collection_id = page.current_url.split('/').last

    # CREATE THE ITEM
    click_link_or_button 'Dashboard'
    within "#summary_collection_#{collection_id}" do
      click_link_or_button '+ Deposit to this collection'
    end

    # Selects image type
    find('label', text: 'Image').click

    # Route to work deposit view
    click_link_or_button 'Continue'

    # Work Deposit view
    find_by_id('work_upload_type_globus').click

    fill_in 'Title of deposit', with: item_title
    fill_in 'Contact email', with: user_email
    fill_in 'work_authors_attributes_0_first_name', with: 'Dana'
    fill_in 'work_authors_attributes_0_last_name', with: 'Scully'
    fill_in 'Abstract', with: "An abstract for #{collection_title} logo"
    fill_in 'Keyword', with: 'Integration test'

    # if you have previously agreed to the terms within the last year, there will be no checkbox
    check('I agree to the SDR Terms of Deposit') if page.has_css?('#work_agree_to_terms', wait: 0)

    # Mark globus upload as complete
    find_button('Save as draft').click
    expect(page).to have_text('Draft - Not deposited')
    click_link_or_button 'Edit or Deposit'
    check('Check this box once all your files have completed uploading to Globus.')
    click_deposit_and_handle_terms_modal

    expect(page).to have_text 'You have successfully deposited your work'
    click_link_or_button 'Return to dashboard'
    click_link_or_button item_title

    # Checks if title is on resulting display
    expect(page).to have_text(item_title)
    expect(page).to have_text('Deposited') # async - it might take a bit

    # Opens Argo and searches on title
    visit Settings.argo_url
    find_field('Search...').send_keys("\"#{item_title}\"", :enter)
    # Click on link with the item's title in the search results
    within '.document-title-heading' do
      click_link_or_button
    end
    bare_druid = page.current_url.split(':').last
    puts " *** h2 object creation druid: #{bare_druid} ***" # useful for debugging
    reload_page_until_timeout!(text: 'v1 Accessioned')
    expect(page).to have_text('my-icons-collection/license/license.pdf')
  end
end
