# frozen_string_literal: true

# Shared examples for initial object registration as most
# integration tests start with registering an object.
#
# Usage:
#   it_behaves_like 'a register object action',
#     object_id: [required: test name (i.e: access_indexing_spec, goobi_accessioning_spec, etc...)]
#     source_id: [required],
#     label: [required],
#     collection: [default: 'integration-testing'],
#     apo: [default: 'integration-testing'],
#     content_type: [default: nil],
#     initial_workflow: [default: nil],
#     project: [default: nil],
#     tags: [default: nil]
RSpec.shared_examples 'an SDR object registion' do
  let(:start_url) { "#{Settings.argo_url}/registration" }
  let(:collection_for_registration) { defined?(collection) ? collection : 'integration-testing' }
  let(:apo_for_registration) { defined?(apo) ? apo : 'integration-testing' }
  let(:type) { defined?(content_type) ? content_type : nil }
  let(:workflow) { defined?(initial_workflow) ? initial_workflow : nil }
  let(:project_name) { defined?(project) ? project : nil }
  let(:project_tags) { defined?(tags) ? tags : nil }
  let(:object_label) { "#{spec_name.humanize} object for #{random_phrase}" }
  let(:default_source_id) { "#{spec_name.dasherize}:#{SecureRandom.uuid}" }
  let(:source_id) { defined?(virtual_source_id) ? virtual_source_id : default_source_id }
  let(:folio_instance_hrid) { defined?(folio_hrid) ? folio_hrid : nil }

  before do
    authenticate!(start_url:, expected_text: 'Register DOR Items')
  end

  it 'uses Argo to register an object' do
    select apo_for_registration, from: 'Admin Policy'
    select collection_for_registration, from: 'Collection'
    select type, from: 'Content Type' if type
    select workflow, from: 'Initial Workflow' if workflow
    fill_in 'Project Name', with: project_name if project_name
    fill_in 'Tags', with: project_tags if project_tags

    fill_in 'Source ID', with: source_id
    fill_in 'Folio Instance HRID', with: folio_instance_hrid if folio_instance_hrid
    fill_in 'Label', with: object_label

    click_button 'Register'

    # wait for object to be registered
    expect(page).to have_text 'Items successfully registered.'

    bare_object_druid = find('table a').text
    druid = "druid:#{bare_object_druid}"
    puts " *** Registered druid: #{druid} ***" # useful for debugging
    save_test_data(spec_name:, data: { 'druid' => druid, 'title' => object_label })
  end
end
