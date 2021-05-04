# frozen_string_literal: true

# NOTE: this spec is intended for use testing changes to dor-services-app mappings to cocina and
#  testing changes to dor_indexing_app to index access from cocina
#  to run:  bundle exec rspec --tag indexing spec/features/access_indexing_spec.rb
RSpec.describe 'Argo rights changes result in correct Access Rights facet value', type: :feature, indexing: true do
  let(:random_word) { RandomWord.phrases.next }
  let(:object_label) { "Object Label for #{random_word}" }
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:source_id) { "access-rights-test:#{random_word}" }

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Register DOR Items')
  end

  scenario do
    # fill in registration form
    select 'integration-testing', from: 'Admin Policy'
    select 'integration-testing', from: 'Collection'
    click_button 'Add Row'
    td_list = all('td.invalidDisplay')
    td_list[0].click
    fill_in '1_source_id', with: source_id
    td_list[1].click
    fill_in '1_label', with: object_label
    find_field('1_label').send_keys :enter

    click_button('Register')
    # wait for object to be registered
    find('td[aria-describedby=data_status][title=success]')
    object_druid = find('td[aria-describedby=data_druid]').text
    # puts "object_druid: #{object_druid}" # useful for debugging

    visit "#{Settings.argo_url}/view/#{object_druid}"

    # wait for registrationWF to finish
    reload_page_until_timeout!(text: 'v1 Registered', with_reindex: true)

    find_access_rights_single_facet_value(object_druid, 'world')

    choose_rights('Stanford')
    find_access_rights_single_facet_value(object_druid, 'stanford')

    choose_rights('Location: Music Library')
    find_access_rights_single_facet_value(object_druid, 'location: music')

    choose_rights('Citation Only')
    find_access_rights_single_facet_value(object_druid, 'citation')

    choose_rights('Dark (Preserve Only)')
    find_access_rights_single_facet_value(object_druid, 'dark')

    choose_rights('Controlled Digital Lending (no-download)')
    find_access_rights_single_facet_value(object_druid, 'controlled digital lending')

    choose_rights('World (no-download)')
    find_access_rights_single_facet_value(object_druid, 'world (no-download)')

    choose_rights('Stanford (no-download)')
    find_access_rights_single_facet_value(object_druid, 'stanford (no-download)')

    # FIXME: in this context, we don't have a no-download option for location specific, but we need it.

    # this isn't in the pull down; discussed with Andrew:
    #  "the rights menu is definitely in my domain. I’ll talk with Astrid.
    #   For the current UI, as long as XML is editable, it’s going to stay as is"
    # choose_rights('Location: Music Library (no-download)')
    # find_access_rights_single_facet_value(object_druid, 'location: music (no-download)')

    # add file level tests
  end
end

def find_access_rights_single_facet_value(druid, facet_value)
  fill_in 'Search...', with: druid
  click_button 'Search'
  click_button('Access Rights')
  within '#facet-rights_descriptions_ssim ul.facet-values' do
    within 'li' do
      find_link(facet_value)
      find('.facet-count', text: 1)
    end
  end
end

def choose_rights(value)
  # go to record view
  within '.index_title' do
    click_link
  end

  find_link('Set rights').click
  within '#blacklight-modal' do
    select(value)
    click_button 'Update'
  end
end
