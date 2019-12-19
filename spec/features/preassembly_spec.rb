# frozen_string_literal: true
require 'io/console'
require 'random_word'
require 'timeout'

RSpec.describe 'Ingest from preassembly', type: :feature do
  after do
    clear_downloads
  end

  scenario 'create a preassembly job' do
    print "SUNet ID: "
    username = gets
    username.strip!
    print "Password: "
    password = $stdin.noecho(&:gets)
    password.strip!
    puts

    visit 'https://sul-preassembly-stage.stanford.edu/'
    fill_in 'SUNet ID', with: username
    fill_in 'Password', with: password
    sleep 1
    click_button 'Login'

    within_frame('duo_iframe') {
      click_button 'Send Me a Push'
    }

    using_wait_time 100 do
      expect(page).to have_content 'Complete the form below'
    end

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
    sleep 30
    save_and_open_page
  end
end
