# frozen_string_literal: true
require 'io/console'
require 'random_word'
require 'timeout'

RSpec.describe 'Reaccession from preassembly', type: :feature do
  after do
    clear_downloads
  end

  # This druid is pre-loaded in /dor/staging/jcoyne-test
  let(:druid) { 'druid:bq653yd1233' }

  scenario 'create a preassembly job' do
    print "SUNet ID: "
    username = gets
    username.strip!
    print "Password: "
    password = $stdin.noecho(&:gets)
    password.strip!
    puts

    visit "https://argo-stage.stanford.edu/view/#{druid}"
    fill_in 'SUNet ID', with: username
    fill_in 'Password', with: password
    sleep 1
    click_button 'Login'

    within_frame('duo_iframe') {
      click_button 'Send Me a Push'
    }

    using_wait_time 100 do
      # Once we see this we know the log in succeeded.
      expect(page).to have_content 'Datastreams'
    end

    # Get the original version from the page
    elem = find('dd.blacklight-status_ssi', text: "Accessioned")
    md = /^v(\d+) Accessioned/.match(elem.text)
    version = md[1].to_i

    visit 'https://sul-preassembly-stage.stanford.edu/'

    expect(page).to have_content 'Complete the form below'

    fill_in 'Project name', with: "#{RandomWord.adjs.next}-#{RandomWord.nouns.next}"
    select 'Pre Assembly Run', from: 'Job type'
    fill_in 'Bundle dir', with: '/dor/staging/jcoyne-test'
    select 'Filename', from: 'Content metadata creation'

    click_button 'Submit'

    expect(page).to have_content 'Success! Your job is queued. A link to job output will be emailed to you upon completion.'

    first('td  > a').click # Click to the job details page

    # Wait for the background job to finish:
    Timeout.timeout(100) do
      loop do
        page.evaluate_script("window.location.reload()")
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
        page.evaluate_script("window.location.reload()")
        break if page.has_text?("v#{version + 1} Accessioned")
      end
    end
  end
end
