# frozen_string_literal: true

RSpec.describe 'Use H2 to create a collection and a versioned work belonging to it' do
  let(:collection_title) { random_phrase }
  let(:item_title) { "SUL Logo for #{collection_title}" }
  let(:user_email) { "#{AuthenticationHelpers.username}@stanford.edu" }

  before do
    authenticate!(start_url: "#{Settings.h2_url}/dashboard", expected_text: /Dashboard|Continue your deposit/)
  end

  scenario do
    # remove modal for deposit in progress, if present, waiting a bit for some rendering
    click_link_or_button 'No' if page.has_text?('Continue your deposit', wait: Settings.timeouts.h2_terms_modal_wait)

    # CREATE COLLECTION
    click_link_or_button '+ Create a new collection'
    # Checks for specific content in create collection view
    expect(page).to have_text('Manage release of deposits for discovery and download')

    # basic collection information
    fill_in 'Collection name', with: collection_title
    fill_in 'Description', with: "Version integration tests for #{collection_title}"
    fill_in 'Contact email', with: user_email

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

    # DEPOSIT AN ITEM
    click_link_or_button 'Dashboard'
    within "#summary_collection_#{collection_id}" do
      click_link_or_button 'Deposit to this collection'
    end

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

    click_deposit_and_handle_terms_modal

    expect(page).to have_text 'You have successfully deposited your work'
    click_link_or_button 'Return to dashboard'
    click_link_or_button item_title

    # Checks if title is on resulting display
    expect(page).to have_text(item_title)
    expect(page).to have_text(Settings.purl_url) # async - it might take a bit

    bare_druid = find('a.copy-button')[:href][-11, 11]
    puts " *** h2 object creation druid: #{bare_druid} ***" # useful for debugging

    # Opens Argo detail page
    visit Settings.argo_url
    expect(page).to have_text('Welcome to Argo!')

    visit "#{Settings.argo_url}/view/#{bare_druid}"
    reload_page_until_timeout!(text: 'v1 Accessioned')

    expect(page).to have_text('Initial version (Public version 1)')

    # give preservation a chance to catch up before we create a new version
    #  since the shelving step does diffs that depend on files being visible in preservation
    sleep 5

    # Deposit without creating a new user version
    visit "#{Settings.h2_url}/dashboard"
    click_link_or_button "Edit #{item_title}"
    choose('No') # Do you want to create a new version of this deposit?
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

    expect(page).to have_text('abstract (Public version 1)')

    # Deposit with creating a new user version
    visit "#{Settings.h2_url}/dashboard"
    click_link_or_button "Edit #{item_title}"
    choose('Yes') # Do you want to create a new version of this deposit?
    fill_in 'What\'s changing?', with: 'adding file'
    attach_file('spec/fixtures/argo-home.png') do
      find_by_id('work_upload_type_browser').click
      find_button('Choose files').click
    end

    click_deposit_and_handle_terms_modal

    expect(page).to have_text 'You have successfully deposited your work'

    # Opens Argo detail page
    visit "#{Settings.argo_url}/view/#{bare_druid}"
    # wait for accessioningWF to finish; retry if error on shelving step, likely caused by a race condition
    reload_page_until_timeout_with_wf_step_retry!(expected_text: 'v3 Accessioned',
                                                  workflow: 'accessionWF',
                                                  workflow_retry_text: 'Error: shelve : problem with shelve',
                                                  retry_wait: 10)

    expect(page).to have_text('adding file (Public version 2)')

    # Go to public version 1, which can be withdrawn
    click_link_or_button 'Public version 1'
    expect(page).to have_text('You are viewing an older public version.')
    accept_confirm 'Once you withdraw this version, the Purl will no longer display it. Are you sure?' do
      click_link_or_button 'Withdraw'
    end
    expect(page).to have_text('Withdrawn.')

    # Verify that changes are reflected in purl service
    visit "#{Settings.purl_url}/#{bare_druid}?version_feature=true"
    reload_page_until_timeout!(text: 'Versions')
    expect(find_table_cell_following(header_text: 'Version 2', xpath_suffix: '[2]').text)
      .to eq('You are viewing this version | Copy URL')
    expect(find_table_cell_following(header_text: 'Version 1', xpath_suffix: '[2]').text)
      .to eq('Withdrawn')
    visit "#{Settings.purl_url}/#{bare_druid}/version/1?version_feature=true"
    expect(page).to have_text('This version has been withdrawn')
    expect(page).to have_no_text('Versions')

    # Now restore it.
    visit "#{Settings.argo_url}/view/#{bare_druid}"
    click_link_or_button 'Public version 1'
    expect(page).to have_text('You are viewing an older public version.')
    click_link_or_button 'Restore'
    expect(page).to have_text('Restored.')

    # Verify that changes are reflected in purl service
    visit "#{Settings.purl_url}/#{bare_druid}?version_feature=true"
    reload_page_until_timeout!(text: 'View | Copy URL')
    expect(page).to have_text('Versions')
    expect(find_table_cell_following(header_text: 'Version 2', xpath_suffix: '[2]').text)
      .to eq('You are viewing this version | Copy URL')
    expect(find_table_cell_following(header_text: 'Version 1', xpath_suffix: '[2]').text)
      .to eq('View | Copy URL')
  end
end
