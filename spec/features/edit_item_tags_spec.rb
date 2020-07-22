# frozen_string_literal: true

RSpec.describe 'Use Argo to edit administrative tags for a single item', type: :feature do
  let(:start_url) do
    "#{Settings.argo_url}/catalog?f%5BobjectType_ssim%5D%5B%5D=item&f%5Bprocessing_status_text_ssi%5D%5B%5D=Accessioned"
  end

  before do
    authenticate!(start_url: start_url, expected_text: 'You searched for:')
  end

  scenario do
    # Grab the first APO
    within('#documents') do
      first('h3 > a').click
    end

    # Make sure we're on an item show view
    expect(page).to have_content 'View in new window'
    object_type_element = find('dd.blacklight-objecttype_ssim')
    expect(object_type_element.text).to eq('item')

    item_druid = find('dd.blacklight-id').text

    # Add tags
    first_new_tag = "#{RandomWord.nouns.next} : #{RandomWord.nouns.next}"
    second_new_tag = "#{RandomWord.nouns.next} : #{RandomWord.nouns.next} : #{RandomWord.nouns.next}"
    click_link 'Edit tags'
    within('#blacklight-modal') do
      fill_in 'new_tag1', with: first_new_tag
      fill_in 'new_tag2', with: second_new_tag
      click_button 'Add'
    end
    expect(page).to have_content "Tags for #{item_druid} have been updated!"
    within('dd.blacklight-tag_ssim') do
      expect(page).to have_content first_new_tag
      expect(page).to have_content second_new_tag
    end

    # Edit tags
    replacement_tag = "#{RandomWord.nouns.next} : #{RandomWord.nouns.next}"
    click_link 'Edit tags'
    within('#blacklight-modal') do
      find(:xpath, "//input[@value='#{first_new_tag}']").fill_in(with: replacement_tag)
      click_button 'Update'
    end
    expect(page).to have_content "Tags for #{item_druid} have been updated!"
    within('dd.blacklight-tag_ssim') do
      expect(page).to have_content replacement_tag
      expect(page).to have_content second_new_tag
    end

    # Remove tags
    click_link 'Edit tags'
    within('#blacklight-modal') do
      find(:xpath, "//input[@value='#{replacement_tag}']/..").first('a').click
    end
    expect(page).to have_content "Tags for #{item_druid} have been updated!"
    within('dd.blacklight-tag_ssim') do
      expect(page).not_to have_content replacement_tag
      expect(page).to have_content second_new_tag
    end
    click_link 'Edit tags'
    within('#blacklight-modal') do
      find(:xpath, "//input[@value='#{second_new_tag}']/..").first('a').click
    end
    expect(page).to have_content "Tags for #{item_druid} have been updated!"
    within('dd.blacklight-tag_ssim') do
      expect(page).not_to have_content replacement_tag
      expect(page).not_to have_content second_new_tag
    end
  end
end
