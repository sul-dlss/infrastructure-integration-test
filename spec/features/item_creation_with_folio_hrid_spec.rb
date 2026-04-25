# frozen_string_literal: true

# Integration: Argo, DSA, Folio
RSpec.describe 'Use Argo to create an item object with a Folio instance HRID', type: :accessioning do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:druid) { test_data[:druid] }
  let(:expected_text) { test_data[:title] }
  let(:test_data) { load_test_data(spec_name: 'item_creation_with_folio_hrid') }
  let(:folio_instance_hrid) { Settings.test_folio_instance_hrid }
  let(:catalog_object_label) { 'The means to prosperity' } # will be pulled from folio
  let(:folio_instance_hrid_updated) { 'a123' }
  let(:catalog_object_label_updated) { 'A la francaise' } # the updated label after we change the hrid
  let(:user_tag) { 'Some : UniqueTagValue' }
  let(:project) { 'Awesome Folio Project' }

  before do
    authenticate!(start_url:, expected_text:)
  end

  scenario do
    # look for metadata
    expect(page).to have_text(user_tag)
    expect(page).to have_text("Project : #{project}")
    expect(page).to have_text(Settings.test_folio_instance_hrid)
    expect(page).to have_text(catalog_object_label) # this was pulled from folio, overwriting used entered label
    expect(page).to have_text("Registered By : #{AuthenticationHelpers.username}")

    # edit folio_instance_hrid
    click_link_or_button 'Manage Folio Instance HRID'
    fill_in 'catalog_record_id_catalog_record_ids_attributes_0_value', with: folio_instance_hrid_updated
    click_link_or_button 'Update'

    # look for updated hrid and refresh metadata
    expect(page).to have_text(folio_instance_hrid_updated)
    click_link_or_button 'Manage description'
    click_link_or_button 'Refresh'
    reload_page_until_timeout!(text: catalog_object_label_updated) # updated label pulled from folio for new HRID

    # look for metadata source facet having an entry of Folio for this druid
    fill_in 'Search...', with: druid
    click_button 'Search'
    click_link_or_button 'Metadata Source'
    within '#facet-metadata_source_ssimdv ul.facet-values' do
      within 'li' do
        find_link('Folio')
        find('.facet-count', text: 1)
      end
    end
  end
end
