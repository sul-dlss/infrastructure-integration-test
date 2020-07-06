# frozen_string_literal: true

RSpec.describe 'Use Hydrus to deposit an item', type: :feature do
  let(:collection_title) { RandomWord.nouns.next }
  let(:item_title) { RandomWord.nouns.next }
  let(:start_url) { 'https://sdr-test.stanford.edu/webauth/login?referrer=/' }
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

    visit "https://argo-stage.stanford.edu/view/#{collection_druid}"
    expect(page).to have_content('View in new window')

    # page does not initially display title, loop until reindexed
    reload_page_until_timeout!(text: collection_title)

    expect(find('dd.blacklight-tag_ssim').text).to include 'Project : Hydrus'
    expect(find('dd.blacklight-project_tag_ssim').text).to eq 'Hydrus'

    visit "https://argo-stage.stanford.edu/view/#{item_druid}"

    # page does not initially display title, loop until reindexed
    reload_page_until_timeout!(text: "Stanford, Jane Lathrop #{item_title}: 2000-01-01")

    expect(find('dd.blacklight-tag_ssim').text).to include 'Project : Hydrus'
    expect(find('dd.blacklight-project_tag_ssim').text).to eq 'Hydrus'
    expect(find('dd.blacklight-is_member_of_collection_ssim').text).to include collection_title
  end
end
