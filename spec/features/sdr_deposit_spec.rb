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
    object_druid = deposit(apo: APO,
                           collection: COLLECTION,
                           url: API_URL,
                           source_id: source_id,
                           catkey: catkey,
                           accession: true,
                           access: 'world',
                           files: ['Gemfile', 'Gemfile.lock'],
                           files_metadata: {
                             'Gemfile' => { 'preserve' => true },
                             'Gemfile.lock' => { 'preserve' => true }
                           })

    visit "#{start_url}view/#{object_druid}?beta=true"

    # Wait for indexing and workflows to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    expect(page).to have_content 'The means to prosperity'

    # Tests existence of technical metadata
    expect(page).to have_content 'Technical metadata'
    file_listing = find_all('#document-techmd-section > ul > li')
    expect(file_listing.size).to be(2)
  end
end
