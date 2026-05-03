# frozen_string_literal: true

# Integration: Argo, DSA, Prescat, SDR API, Stacks
RSpec.describe 'SDR client deposit to SDR API', type: :accessioning do
  let(:start_url) { Settings.argo_url }
  let(:source_id) { "testing:#{SecureRandom.uuid}" }
  let(:folio_instance_hrid) { Settings.test_folio_instance_hrid }

  before do
    authenticate!(start_url:, expected_text: 'Welcome to Argo!')
  end

  after do
    clear_downloads
  end

  it 'deposits objects' do
    druid = deposit(apo: Settings.default_apo,
                    collection: Settings.default_collection,
                    type: Cocina::Models::ObjectType.object,
                    source_id:,
                    folio_instance_hrid:,
                    accession: true,
                    view: 'world',
                    download: 'world',
                    basepath: '.',
                    files: ['Gemfile', 'Gemfile.lock', 'config/settings.yml'],
                    files_metadata: {
                      'Gemfile' => { 'preserve' => true, 'shelve' => false, 'publish' => false },
                      'Gemfile.lock' => { 'preserve' => false, 'shelve' => true, 'publish' => true },
                      'config/settings.yml' => { 'preserve' => true }
                    })
    puts " *** sdr deposit druid: #{druid} ***" # useful for debugging
    save_test_data(spec_name: 'sdr_client_deposit', data: druid)

    visit "#{start_url}/view/#{druid}"
    expect(page).to have_text 'The means to prosperity'
  end
end
