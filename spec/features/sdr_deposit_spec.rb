# frozen_string_literal: true

RSpec.describe 'SDR deposit', type: :feature do
  let(:start_url) { 'https://argo-stage.stanford.edu/' }
  let(:source_id) { "testing:#{SecureRandom.uuid}" }
  let(:catkey) { '10065784' }

  before do
    authenticate!(start_url: start_url, expected_text: 'Welcome to Argo!')
  end

  it 'deposits objects' do
    ensure_token
    result = SdrClient::Deposit.run(apo: APO,
                                    source_id: source_id,
                                    collection: COLLECTION,
                                    catkey: catkey,
                                    url: API_URL,
                                    accession: true,
                                    access: 'world',
                                    files: ['Gemfile', 'Gemfile.lock'],
                                    files_metadata: {
                                      'Gemfile' => { 'preserve' => true },
                                      'Gemfile.lock' => { 'preserve' => true }
                                    })
    object_druid = result[:druid]

    visit "#{start_url}view/#{object_druid}?beta=true"

    # Wait for indexing and workflows to finish
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?('v1 Accessioned')
      end
    end

    expect(page).to have_content 'The means to prosperity'

    # Tests existence of technical metadata
    expect(page).to have_content 'Technical metadata'
    file_listing = find_all('#document-techmd-section > ul > li')
    expect(file_listing.size).to be(2)
  end
end
