# frozen_string_literal: true

# to run:  bundle exec rspec --tag skip_for_default spec/features/embargo_h2_spec.rb
# NOTE: this can only be run on stage as there is no purl page for qa
# NOTE: for an embargo to appear on the purl page, the conditions are:
#  (Cocina)
#    - access data ... with the embargo in it as appropriate
#    - access data correctly put in PURL xml
#  - the object must be of content type file if the embed viewer is to show the embargo;
#    however, the purl xml will show it regardless of type.  the embed viewer is in an iframe and tricky
#    to test via capybara
RSpec.describe 'H2 item created with embargo; change embargo in Argo',
               type: :feature, stage_only: true, embargo: true, skip_for_default: true do
  let(:collection_title) { RandomWord.nouns.next }
  let(:item_title) { "Text file #{RandomWord.nouns.next} in H2 collection" }
  let(:user_email) { "#{AuthenticationHelpers.username}@stanford.edu" }

  before do
    authenticate!(start_url: "#{Settings.h2_url}/dashboard", expected_text: 'Create a new collection')
  end

  scenario do
    click_button 'No' if page.has_content?('Continue your deposit', wait: Settings.post_authentication_text_timeout)
    click_link '+ Create a new collection'

    # Create collection
    expect(page).to have_content('Manage release of deposits for discovery and download')
    fill_in 'Collection name', with: collection_title
    fill_in 'Description', with: "Integration tests for embargo #{collection_title}"
    fill_in 'Contact email', with: user_email
    select 'CC0-1.0', from: 'collection_required_license'
    fill_in 'Depositors', with: AuthenticationHelpers.username

    # set embargo for 6 months for collection members
    choose 'Delay release'

    click_button 'Deposit'
    expect(page).to have_content(collection_title)
    reload_page_until_timeout!(text: "Edit #{collection_title}", as_link: true)

    # Deposit an item to the collection
    find(:table, collection_title).sibling('turbo-frame').first(:button).click
    find('label', text: 'Text').click
    click_button 'Continue'
    expect(page).to have_content('Deposit your content')
    attach_file('spec/fixtures/etd_supplemental.txt') do
      find_button('Choose files').click
    end
    expect(page).to have_content('etd_supplemental.txt')
    fill_in 'Title of deposit', with: item_title
    fill_in 'Contact email', with: user_email
    fill_in 'work_authors_attributes_0_first_name', with: 'Vinsky'
    fill_in 'work_authors_attributes_0_last_name', with: 'Cat'
    fill_in 'Abstract', with: "An abstract for #{collection_title} file"
    fill_in 'Keywords', with: 'embargo integration test'
    # Blur keywords field so the client completes validation
    find_field('work_keywords').native.send_keys(:tab)

    check('I agree to the SDR Terms of Deposit')
    find_button('Deposit').click

    expect(page).to have_content(item_title)
    reload_page_until_timeout!(text: Settings.purl_url)

    # check Argo facet field with 6 month embargo
    visit Settings.argo_url
    find('input#q').fill_in(with: item_title)
    click_button 'Search'
    click_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      expect(page).not_to have_content('up to 7 days')
    end

    within '#documents' do
      click_link item_title
    end
    embargo_date = DateTime.now.utc.to_date >> 6
    expect(page).to have_content("This item is embargoed until #{embargo_date.strftime('%F').tr('-', '.')}")

    # get druid
    druid = page.current_url.split(':').last

    # check purl xml for embargo
    visit "#{Settings.purl_url}/#{druid}.xml"
    expect_embargo_date_in_purl(embargo_date)

    new_embargo_date = Date.today + 3
    visit "#{Settings.argo_url}/view/#{druid}"
    find_link('Update embargo').click
    within '#blacklight-modal' do
      fill_in('embargo_date', with: new_embargo_date.strftime('%F'))
      click_button 'Update Embargo'
    end
    reload_page_until_timeout!(text: "This item is embargoed until #{new_embargo_date.strftime('%F').tr('-', '.')}",
                               with_reindex: true)

    # check Argo facet field with 3 day embargo
    visit "#{Settings.argo_url}/catalog?search_field=text&q=#{druid}"
    click_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      find_link('up to 7 days')
    end

    visit "#{Settings.argo_url}/view/#{druid}"
    # updates the purl XML but may require a hard refresh to update date in embed viewer
    find_link('Republish').click

    # check purl xml for 3 day embargo
    visit "#{Settings.purl_url}/#{druid}.xml"
    expect_embargo_date_in_purl(new_embargo_date)
  end
end

# rubocop:disable Metrics/AbcSize
def expect_embargo_date_in_purl(embargo_date)
  Timeout.timeout(Settings.timeouts.workflow) do
    loop do
      page.driver.browser.navigate.refresh
      break unless html.empty?

      sleep 1
    end
  end

  purl_ng_xml = Nokogiri::XML(html)
  embargo_nodes = purl_ng_xml.xpath('//rightsMetadata/access[@type="read"]/machine/embargoReleaseDate')
  expect(embargo_nodes.size).to eq 1
  expect(embargo_nodes.first.content).to eq embargo_date.strftime('%FT%TZ')
end
# rubocop:enable Metrics/AbcSize
