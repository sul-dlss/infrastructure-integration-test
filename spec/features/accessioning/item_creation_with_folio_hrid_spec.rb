# frozen_string_literal: true

# Integration: Argo, DSA, Folio
RSpec.describe 'Use Argo to create an item object with a Folio instance HRID', type: :accessioning do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:druid) { test_data[:druid] }
  let(:expected_text) { /Keynes, John Maynard, 1883-1946|Amellér, André, 1912-1990/ }
  let(:test_data) { load_test_data(spec_name: 'item_creation_with_folio_hrid') }
  # rubocop:disable RSpec/InstanceVariable
  let(:folio_instance_hrid) { @initial_hrid }
  let(:catalog_object_title) { @initial_title } # will be pulled from folio
  let(:folio_instance_hrid_updated) { @updated_hrid }
  let(:catalog_object_title_updated) { @updated_title } # the updated title after we change the hrid
  # rubocop:enable RSpec/InstanceVariable
  let(:catalog_title) { /A la francaise|The means to prosperity/ }
  let(:user_tag) { 'Some : UniqueTagValue' }
  let(:project) { 'Awesome Folio Project' }

  before do
    authenticate!(start_url:, expected_text:)

    # This swaps the initial and updated hrid and title
    # to allow the test to be rerun without registering a new object
    @initial_hrid = Settings.test_folio_instance_hrid
    @initial_title = 'The means to prosperity'
    @updated_hrid = 'a123'
    @updated_title = 'A la francaise'

    if page.has_content?('a123')
      @initial_hrid = 'a123'
      @initial_title = 'A la francaise'
      @updated_hrid = Settings.test_folio_instance_hrid
      @updated_title = 'The means to prosperity'
    end
  end

  scenario do
    # look for metadata
    expect(page).to have_text(user_tag)
    expect(page).to have_text("Project : #{project}")
    expect(page).to have_text(folio_instance_hrid)
    expect(page).to have_text(catalog_title) # this was pulled from folio, overwriting used entered title
    expect(page).to have_text("Registered By : #{AuthenticationHelpers.username}")

    # edit folio_instance_hrid
    click_link_or_button 'Manage Folio Instance HRID'
    fill_in 'catalog_record_id_catalog_record_ids_attributes_0_value', with: folio_instance_hrid_updated
    click_link_or_button 'Update'

    # look for updated hrid and refresh metadata
    expect(page).to have_text(folio_instance_hrid_updated)
    click_link_or_button 'Manage description'
    click_link_or_button 'Refresh'
    reload_page_until_timeout!(text: catalog_object_title_updated) # updated title pulled from folio for new HRID

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
