# frozen_string_literal: true

RSpec.describe 'Use Hydrus to deposit an item', type: :feature do
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
    collection_druid = current_url.match(%r{collections/(?<druid>druid:.+)})[:druid]
    click_button 'Open Collection'

    expect(page).to have_content 'Collection opened'
    expect(page).to have_content 'Open for deposit'
    click_link 'Items'

    expect(page).to have_content 'Add new item'
    click_button 'Add new item'
    click_link 'image'

    expect(page).to have_content 'Edit Draft'
    item_druid = current_url.match(%r{items/(?<druid>druid:.+)/edit})[:druid]
    fill_in 'Title of item', with: item_title
    fill_in 'Contact email', with: user_email
    find('input#hydrus_item_contributors_0_name').fill_in(with: 'Stanford, Jane Lathrop')
    find('input#hydrus_item_dates_date_created').fill_in(with: '2000-01-01')
    find('input#files_').attach_file('spec/fixtures/sul-logo.png')
    fill_in 'Abstract', with: 'Lorem ipsum, this is the item abstract.'
    fill_in 'Keywords', with: 'Libraries, Digital Library Systems and Services, Infrastructure Team'
    find('input#release_settings').check
    find('input#terms_of_deposit_checkbox').check
    click_button 'Save'

    expect(page).to have_content "'sul-logo.png' uploaded."
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

    visit "#{Settings.argo_url}/view/#{collection_druid}"
    expect(page).to have_content('View in new window')

    # page does not initially display title, loop until reindexed
    reload_page_until_timeout!(text: collection_title)

    expect(find('dd.blacklight-tag_ssim').text).to include 'Project : Hydrus'
    expect(find('dd.blacklight-project_tag_ssim').text).to eq 'Hydrus'
    expect(find('dd.blacklight-rights_descriptions_ssim').text).to eq 'world'

    visit "#{Settings.argo_url}/view/#{item_druid}"

    # page does not initially display title, loop until reindexed
    reload_page_until_timeout!(text: "Stanford, Jane Lathrop #{item_title}: 2000-01-01")

    expect(find('dd.blacklight-tag_ssim').text).to include 'Project : Hydrus'
    expect(find('dd.blacklight-project_tag_ssim').text).to eq 'Hydrus'
    expect(find('dd.blacklight-is_member_of_collection_ssim').text).to include collection_title

    # Test that embargo setting for accessioned objects works fully
    reload_page_until_timeout!(text: 'v1 Accessioned', with_reindex: true)
    embargo_date = DateTime.now.to_date >> 6
    expect(page).to have_content "This item is embargoed until #{embargo_date.strftime('%F').tr('-', '.')}"

    # check Argo facet field (indexed embargo date) with 6 month embargo
    visit "#{Settings.argo_url}/catalog?search_field=text&q=#{item_druid}"
    reload_page_until_timeout!(text: 'Embargo Release Date')
    click_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      expect(page).not_to have_content('up to 7 days')
    end
    bare_druid = item_druid.split(':').last

    # check purl xml for embargo
    expect_embargo_date_in_purl(bare_druid, embargo_date)

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

    # check Argo facet field (indexed embargo date) with 3 day embargo
    visit "#{Settings.argo_url}/catalog?search_field=text&q=#{bare_druid}"
    reload_page_until_timeout!(text: 'Embargo Release Date')
    click_button('Embargo Release Date')
    within '#facet-embargo_release_date ul.facet-values' do
      find_link('up to 7 days')
    end

    # update the purl XML
    visit "#{Settings.argo_url}/view/#{bare_druid}"
    find_link('Republish').click
    sleep 1 # allow purl to get updated
    # check purl xml for 3 day embargo
    expect_embargo_date_in_purl(bare_druid, new_embargo_date)
  end
end
