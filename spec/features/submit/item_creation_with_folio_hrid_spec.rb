# frozen_string_literal: true

# Integration: Argo, DSA, Folio
RSpec.describe 'Use Argo to create an item object with a Folio instance HRID' do
  let(:random_word) { random_phrase }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:source_id) { "create-obj-folio-instance-hrid-test:#{random_alpha}" }
  let(:folio_instance_hrid) { Settings.test_folio_instance_hrid }
  let(:catalog_object_label) { 'The means to prosperity' } # will be pulled from folio
  let(:folio_instance_hrid_updated) { 'a123' }
  let(:catalog_object_label_updated) { 'A la francaise' } # the updated label after we change the hrid
  let(:user_tag) { 'Some : UniqueTagValue' }
  let(:project) { 'Awesome Folio Project' }

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  scenario do
    # fill in registration form
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    select 'book', from: 'Content Type'
    fill_in 'Tag', with: user_tag
    fill_in 'Project Name', with: project

    fill_in 'Source ID', with: source_id
    fill_in 'Folio Instance HRID', with: folio_instance_hrid
    fill_in 'Label', with: object_label # will be overwritten and checked below

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    object_druid = "druid:#{bare_object_druid}"
    puts " *** create folio object spec druid: #{object_druid} ***" # useful for debugging

    visit "#{Settings.argo_url}/view/#{object_druid}"

    # wait for registrationWF to finish
    reload_page_until_timeout!(text: 'v1 Registered')

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
    fill_in 'Search...', with: object_druid
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
