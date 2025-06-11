# frozen_string_literal: true

RSpec.describe 'Use H3 to create a collection and an item object belonging to it with files from globus' do
  # Including "Integration Test" in the title causes H3 to use the configured integration test
  # globus endpoint, which already has files.
  let(:collection_title) { "#{random_phrase} Integration Test" }
  let(:item_title) { "My Icon Collection for #{collection_title}" }
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

    # there is a pre-set endpoint with the globus files ready to go when the title includes "Integration Test"
    click_link_or_button 'Use Globus to transfer files'
    click_link_or_button 'Globus file transfer complete'

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
    expect(page).to have_text('my-icons-collection/license/license.pdf')
  end
end
