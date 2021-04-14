# frozen_string_literal: true

# NOTE: this can only be run on stage as there is no purl page for qa
# NOTE: this should be incorporated into the hydrus test once we have all the embargo pieces,
#   including dor-indexing-app and dor-services-app, using native cocina as a source
# NOTE: for an embargo to appear on the purl page, the conditions are:
#  (Fedora)
#    - there must be contentMetadata
#    - there must be rightsMetadata
#    - there must be embargoMetadata
#  (Cocina)
#    - access data ... with the embargo in it as appropriate
#    - access data correctly put in PURL xml
#  - the object must be of content type file if the embed viewer is to show the embargo;
#    however, the purl xml will show it regardless of type.  the embed viewer is in an iframe and tricky
#    to test via capybara
RSpec.describe 'Hydrus object created with embargo; change embargo in Argo',
               type: :feature, stage_only: true, embargo: true do
  let(:collection_title) { RandomWord.nouns.next }
  let(:item_title) { RandomWord.nouns.next }
  let(:start_url) { "#{Settings.hydrus_url}/webauth/login?referrer=/" }
  let(:user_email) { "#{AuthenticationHelpers.class_variable_get(:@@username)}@stanford.edu" }

  before do
    authenticate!(start_url: start_url, expected_text: 'Create a new collection')
  end

  scenario do
    click_link 'Create a new collection'
    expect(page).to have_content 'Name, description, contact'
    expect(page).to have_content 'Closed for deposit'

    fill_in 'Collection name', with: collection_title
    fill_in 'Description', with: 'Lorem ipsum yada yada yada.'
    fill_in 'Contact email', with: user_email
    choose 'hydrus_collection_embargo_option_fixed'
    select('6 months after deposit', from: 'embargo_option_fixed')
    click_button 'Save'
    expect(page).to have_content collection_title
    click_button 'Open Collection'
    expect(page).to have_content 'Collection opened'
    expect(page).to have_content 'Open for deposit'

    click_link 'Items'
    expect(page).to have_content 'Add new item'
    click_button 'Add new item'
    click_link 'class project'

    expect(page).to have_content 'Edit Draft'
    item_druid = current_url.match(%r{items/(?<druid>druid:.+)/edit})[:druid]
    fill_in 'Title of item', with: item_title
    fill_in 'Contact email', with: user_email
    find('input#hydrus_item_contributors_0_name').fill_in(with: 'Stanford, Jane Lathrop')
    find('input#hydrus_item_dates_date_created').fill_in(with: '2000-01-01')
    find('input#files_').attach_file('spec/fixtures/etd_supplemental.txt')
    fill_in 'Abstract', with: 'Lorem ipsum, this is the item abstract.'
    fill_in 'Keywords', with: 'Libraries, Digital Library Systems and Services, Infrastructure Team'
    find('input#release_settings').check
    find('input#terms_of_deposit_checkbox').check
    click_button 'Save'

    expect(page).to have_content "'etd_supplemental.txt' uploaded."
    expect(page).to have_content 'Your changes have been saved.'
    expect(page).to have_content 'Draft'
    expect(page).to have_content item_title
    click_button 'Publish'

    expect(page).to have_content 'Item published: v1.0.0.'

    within('.breadcrumb') do
      click_link collection_title
    end
    expect(page).to have_link 'Items'
    click_link 'Items'
    expect(page).to have_content item_title
    expect(page).to have_content 'published'
    click_button 'Close Collection'
    expect(page).to have_content 'Collection closed'
    expect(page).to have_content 'Closed for deposit'

    visit "#{Settings.argo_url}/view/#{item_druid}"
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)
    embargo_date = DateTime.now.to_date >> 6
    expect(page).to have_content "This item is embargoed until #{embargo_date.strftime('%F').tr('-', '.')}"

    # check Argo facet field with 6 month embargo
    visit "#{Settings.argo_url}/catalog?search_field=text&q=#{item_druid}"
    click_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      expect(page).not_to have_content('up to 7 days')
    end
    bare_druid = item_druid.split(':').last

    # ideally, also would look for the following on purl page:
    #   "Access is restricted until #{embargo_date.strftime('%d-%b-%Y')}"
    # but this is in the embed file viewer within an iframe and I couldn't figure it out.

    # check purl xml for embargo
    visit "#{Settings.purl_url}/#{bare_druid}.xml"
    expect_embargo_date_in_purl(embargo_date)

    # change embargo date
    new_embargo_date = Date.today + 3
    visit "#{Settings.argo_url}/view/#{bare_druid}"
    find_link('Update embargo').click
    within '#blacklight-modal' do
      fill_in('embargo_date', with: new_embargo_date.strftime('%F'))
      click_button 'Update Embargo'
    end
    reload_page_until_timeout!(text: "This item is embargoed until #{new_embargo_date.strftime('%F').tr('-', '.')}",
                               with_reindex: true)

    # check Argo facet field with 3 day embargo
    visit "#{Settings.argo_url}/catalog?search_field=text&q=#{bare_druid}"
    click_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      find_link('up to 7 days')
    end
    visit "#{Settings.argo_url}/view/#{bare_druid}"
    # updates the purl XML but may require a hard refresh to update date in embed viewer
    find_link('Republish').click

    # check purl xml for 3 day embargo
    visit "#{Settings.purl_url}/#{bare_druid}.xml"
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
