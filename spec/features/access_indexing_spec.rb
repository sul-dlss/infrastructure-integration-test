# frozen_string_literal: true

# Integration: Argo facets, Cocina Models mappings, DSA Solr indexing
RSpec.describe 'Argo rights changes result in correct Access Rights facet value', type: :accessioning do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:druid) { test_data[:druid] }
  let(:title) { test_data[:title] }
  let(:test_data) { load_test_data(spec_name: 'access_indexing') }

  before do
    authenticate!(start_url:, expected_text: title)
  end

  scenario do
    puts " *** access indexing druid: #{druid} ***" # useful for debugging

    expect(page).to have_text 'v1 Registered'

    find_access_rights_single_facet_value(druid:, facet_value: 'world')

    choose_rights(view: 'Stanford', download: 'Stanford')
    find_access_rights_single_facet_value(druid:, facet_value: 'stanford')

    choose_rights(view: 'Citation only')
    find_access_rights_single_facet_value(druid:, facet_value: 'citation')

    choose_rights(view: 'Dark')
    find_access_rights_single_facet_value(druid:, facet_value: 'dark')

    choose_rights(view: 'World', download: 'None')
    find_access_rights_single_facet_value(druid:, facet_value: 'world (no-download)')

    choose_rights(view: 'Stanford', download: 'None')
    find_access_rights_single_facet_value(druid:, facet_value: 'stanford (no-download)')

    # NOTE: For some reason, moving this test down helped it pass. :shrug:
    choose_rights(view: 'Location based', download: 'Location based', location: 'music')
    find_access_rights_single_facet_value(druid:, facet_value: 'location: music')
  end
end

def find_access_rights_single_facet_value(druid:, facet_value:)
  fill_in 'Search...', with: druid
  click_button 'Search'
  click_link_or_button('Access Rights')

  within '#facet-rights_descriptions_ssimdv ul.facet-values' do
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
