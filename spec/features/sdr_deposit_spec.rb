# frozen_string_literal: true

RSpec.describe 'SDR deposit', type: :feature do
  let(:start_url) { 'https://argo-stage.stanford.edu/' }
  let(:api_url) { 'https://sdr-api-stage.stanford.edu' }
  let(:source_id) { "testing:#{SecureRandom.uuid}" }
  let(:apo) { 'druid:sc012gz0974' }
  let(:collection) { 'druid:hv320hk4091' }
  let(:catkey) { '10065784' }

  before do
    authenticate!(start_url: start_url, expected_text: 'Welcome to Argo!')
  end

  # This allows a login using credentials from the environment.
  class LoginFromEnv
    def self.run
      { email: ENV.fetch('SDR_EMAIL'), password: ENV.fetch('SDR_PASSWORD') }
    end
  end

  it 'deposits objects' do
    SdrClient::Login.run(url: api_url,
                         login_service: LoginFromEnv)

    result = SdrClient::Deposit.run(apo: apo,
                                    source_id: source_id,
                                    collection: collection,
                                    catkey: catkey,
                                    url: api_url,
                                    files: ['Gemfile', 'Gemfile.lock'])
    object_druid = result[:druid]

    visit "#{start_url}/view/#{object_druid}"

    # Wait for indexing and workflows to finish
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?('v1 Accessioned')
      end
    end

    expect(page).to have_content 'The means to prosperity'
  end
end
