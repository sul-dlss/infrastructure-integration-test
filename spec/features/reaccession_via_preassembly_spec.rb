# frozen_string_literal: true

require 'io/console'
require 'random_word'
require 'timeout'

RSpec.describe 'Reaccession from preassembly', type: :feature do
  # This druid is pre-loaded in /dor/staging/jcoyne-test
  let(:druid) { 'druid:vy293gd2473' }
  let(:start_url) { "https://argo-stage.stanford.edu/view/#{druid}" }

  before do
    authenticate!(start_url: start_url,
                  expected_text: 'Datastreams')
  end

  after do
    clear_downloads
  end

  scenario do
    # Get the original version from the page
    elem = find('dd.blacklight-status_ssi', text: 'Accessioned')
    md = /^v(\d+) Accessioned/.match(elem.text)
    version = md[1].to_i

    visit 'https://sul-preassembly-stage.stanford.edu/'

    expect(page).to have_content 'Complete the form below'

    fill_in 'Project name', with: "#{RandomWord.adjs.next}-#{RandomWord.nouns.next}"
    select 'Pre Assembly Run', from: 'Job type'
    fill_in 'Bundle dir', with: '/dor/staging/integration-tests'
    select 'Filename', from: 'Content metadata creation'

    click_button 'Submit'

    exp_str = 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'
    expect(page).to have_content exp_str

    first('td  > a').click # Click to the job details page

    # Wait for the background job to finish:
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_link?('Download')
      end
    end

    click_link 'Download'

    wait_for_download

    yaml = YAML.load_file(download)
    expect(yaml[:status]).to eq 'success'

    visit "https://argo-stage.stanford.edu/view/druid:#{yaml[:pid]}"

    # Wait for the accessioningWF to finish:
    Timeout.timeout(100) do
      loop do
        page.evaluate_script('window.location.reload()')
        break if page.has_text?("v#{version + 1} Accessioned")
      end
    end
  end
end
