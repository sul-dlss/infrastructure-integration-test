# frozen_string_literal: true

# for testing changes to dor-services-app mappings to cocina and
#   testing changes to dor_indexing_app to index access from cocina
RSpec.describe 'Argo rights changes result in correct Access Rights facet value' do
  let(:random_word) { random_phrase }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:source_id) { "access-rights-test:#{random_word}" }

  before do
    authenticate!(start_url:,
                  expected_text: 'Register DOR Items')
  end

  scenario do
    # fill in registration form
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'

    fill_in 'Source ID', with: source_id
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    object_druid = "druid:#{bare_object_druid}"
    puts " *** access indexing druid: #{object_druid} ***" # useful for debugging

    visit "#{Settings.argo_url}/view/#{object_druid}"

    # wait for registrationWF to finish
    reload_page_until_timeout!(text: 'v1 Registered')

    find_access_rights_single_facet_value(object_druid, 'world')

    choose_rights(view: 'Stanford', download: 'Stanford')
    find_access_rights_single_facet_value(object_druid, 'stanford')

    choose_rights(view: 'Citation only')
    find_access_rights_single_facet_value(object_druid, 'citation')

    choose_rights(view: 'Dark')
    find_access_rights_single_facet_value(object_druid, 'dark')

    choose_rights(view: 'World', download: 'None')
    find_access_rights_single_facet_value(object_druid, 'world (no-download)')

    choose_rights(view: 'Stanford', download: 'None')
    find_access_rights_single_facet_value(object_druid, 'stanford (no-download)')

    # NOTE: For some reason, moving this test down helped it pass. :shrug:
    choose_rights(view: 'Location based', download: 'Location based', location: 'music')
    find_access_rights_single_facet_value(object_druid, 'location: music')

    # FIXME: in this context, we don't have a no-download option for location specific, but we need it.
    # this isn't in the pull down; discussed with Andrew:
    #  "the rights menu is definitely in my domain. I’ll talk with Astrid.
    #   For the current UI, as long as XML is editable, it’s going to stay as is"
    # choose_rights('Location: Music Library (no-download)')
    # find_access_rights_single_facet_value(object_druid, 'location: music (no-download)')

    # this is last as choose_rights doesn't have a handy way to turn controlled digital lending off.
    choose_rights(view: 'Stanford', download: 'None', cdl: true)
    find_access_rights_single_facet_value(object_druid, 'controlled digital lending')

    # TODO: add file level tests
  end
end

def find_access_rights_single_facet_value(druid, facet_value)
  fill_in 'Search...', with: druid
  click_button 'Search'
  click_link_or_button('Access Rights')

  within '#facet-rights_descriptions_ssim ul.facet-values' do
    within 'li' do
      find_link(facet_value)
      find('.facet-count', text: 1)
    end
  end
end

def choose_rights(view:, download: nil, location: nil, cdl: false)
  # go to record view
  within '.index_title' do
    click_link_or_button
  end

  click_link_or_button 'Edit rights'
  within '#access-rights' do
    select view, from: 'item_view_access'
    select download, from: 'item_download_access' if download
    select location, from: 'item_access_location' if location
    select 'Yes', from: 'Controlled digital lending' if cdl
    click_link_or_button 'Save'
  end

  # It takes a few milliseconds for the rights update to take
  expect(page).to have_text(view_label(view:, location:, cdl:))
end

def view_label(view:, location:, cdl:)
  return 'CDL' if cdl
  return "View: Location: #{location}" if location
  return 'View: Citation-only' if view == 'Citation only'

  "View: #{view}"
end
