# frozen_string_literal: true
require 'io/console'
require 'random_word'

RSpec.describe 'Use Argo to create a collection', type: :feature do
  let(:collection_title) { RandomWord.phrases.next }
  let(:collection_abstract) { 'Created by https://github.com/sul-dlss/infrastructure-integration-test' }
  let(:start_url) do
    'https://argo-stage.stanford.edu/catalog?f%5BobjectType_ssim%5D%5B%5D=adminPolicy&f%5Bprocessing_status_text_ssi%5D%5B%5D=Accessioned'
  end

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'You searched for:')
  end

  scenario do
    # Grab the first APO
    within('#documents') do
      first('h3 > a').click
    end

    # Make sure we're on an APO show view
    expect(page).to have_content 'View in new window'
    object_type_element = find('dd.blacklight-objecttype_ssim')
    expect(object_type_element.text).to eq('adminPolicy')

    apo_druid = find('dd.blacklight-id').text

    click_link 'Create Collection'

    within('#blacklight-modal') do
      fill_in 'Collection Title', with: collection_title
      fill_in 'Collection Abstract', with: collection_abstract
      click_button 'Register Collection'
    end

    expect(page).to have_content 'Created collection'

    collection_druid = find('.alert-info').text.split[2]
    visit "https://argo-stage.stanford.edu/view/#{collection_druid}"

    expect(page).to have_content collection_title

    object_type_element = find('dd.blacklight-objecttype_ssim')
    expect(object_type_element.text).to eq('collection')

    apo_element = first('dd.blacklight-is_governed_by_ssim > a')
    expect(apo_element[:href]).to end_with(apo_druid)

    # Wait for workflows to finish
    Timeout.timeout(100) do
      loop do
        page.evaluate_script("window.location.reload()")
        break if page.has_text?("v1 Accessioned")
      end
    end
  end
end
