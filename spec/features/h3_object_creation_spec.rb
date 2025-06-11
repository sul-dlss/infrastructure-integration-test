# frozen_string_literal: true

RSpec.describe 'Use H3 to create a collection and an item object belonging to it and version it' do
  let(:collection_title) { random_phrase }
  let(:item_title) { "SUL Logo for #{collection_title}" }
  let(:user_email) { "#{AuthenticationHelpers.username}@stanford.edu" }

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

    # Work Deposit view
    find('.dropzone').drop('spec/fixtures/sul-logo.png')

    expect(page).to have_text('sul-logo.png')

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
    fill_in 'First name', with: 'Dana'
    fill_in 'Last name', with: 'Scully'

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
    expect(page).to have_text('Initial version (Public version 1)') # we have an initial public version 1 in Argo
    expect_text_on_purl_page(druid: work_druid, text: 'Version 1') # check the version display on PURL

    # back to H3, create a new version that only changes metadata, thus not creating a user version
    visit "#{Settings.h3_url}/dashboard"

    click_link_or_button item_title
    click_link_or_button 'Edit or deposit'
    find('.nav-link', text: 'Abstract and keywords').click
    fill_in 'Abstract', with: "A changed abstract for #{collection_title} logo"

    find('.nav-link', text: 'Deposit', exact_text: true).click
    expect(page).to have_text('Submit your deposit')
    fill_in 'What\'s changing?', with: 'changing abstract'

    click_link_or_button 'Deposit', class: 'btn-primary', exact_text: true

    expect(page).to have_css('h1', text: item_title)
    reload_page_until_timeout!(text: 'Deposited')

    # Opens Argo detail page
    visit "#{Settings.argo_url}/view/#{work_druid}"
    # wait for accessioningWF to finish; retry if error on shelving step, likely caused by a race condition
    reload_page_until_timeout_with_wf_step_retry!(expected_text: 'v2 Accessioned',
                                                  workflow: 'accessionWF',
                                                  workflow_retry_text: 'Error: shelve : problem with shelve',
                                                  retry_wait: 10)
    expect(page).to have_text('changing abstract (Public version 1)') # Argo still on user version 1 since only metadata changed
    expect(page).to have_no_text('Public version 2') # and no user version 2
    expect_text_on_purl_page(druid: work_druid, text: 'Version 1') # PURL also still only shows Version 1
    do_not_expect_text_on_purl_page(druid: work_druid, text: 'Version 2') # and no user version 2

    # back to H3, create a new version that changes a file, thus creating a user version
    visit "#{Settings.h3_url}/dashboard"

    click_link_or_button item_title
    click_link_or_button 'Edit or deposit'

    # Add a new file
    find('.dropzone').drop('spec/fixtures/vision_for_stanford.jpg')
    expect(page).to have_text('vision_for_stanford.jpg')

    find('.nav-link', text: 'Deposit', exact_text: true).click
    expect(page).to have_text('Submit your deposit')
    fill_in 'What\'s changing?', with: 'adding a file'

    click_link_or_button 'Deposit', class: 'btn-primary', exact_text: true

    expect(page).to have_css('h1', text: item_title)
    reload_page_until_timeout!(text: 'Deposited')

    # Opens Argo detail page
    visit "#{Settings.argo_url}/view/#{work_druid}"
    # wait for accessioningWF to finish; retry if error on shelving step, likely caused by a race condition
    reload_page_until_timeout_with_wf_step_retry!(expected_text: 'v3 Accessioned',
                                                  workflow: 'accessionWF',
                                                  workflow_retry_text: 'Error: shelve : problem with shelve',
                                                  retry_wait: 10)
    expect(page).to have_text('adding a file (Public version 2)') # now we are on user version 2 since we added a file
    expect(page).to have_no_text('Public version 3') # and no user version 3
    expect_text_on_purl_page(druid: work_druid, text: 'Version 2') # PURL now shows user version 2
    do_not_expect_text_on_purl_page(druid: work_druid, text: 'Version 3') # and no user version 3
  end
end
