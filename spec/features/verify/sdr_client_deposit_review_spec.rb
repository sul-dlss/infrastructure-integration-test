# frozen_string_literal: true

# Integration: Argo, DSA, Prescat, SDR API, Stacks
RSpec.describe 'Verify SDR client deposit to SDR API', type: :verify do
  let(:start_url) { "#{Settings.argo_url}/view/#{druid}" }
  let(:druid) { load_test_data(spec_name: 'sdr_client_deposit') }

  before do
    authenticate!(start_url:, expected_text: 'The means to prosperity')
  end

  after do
    clear_downloads
  end

  it 'reviews and verifies SdrClient deposited objects' do
    puts " *** sdr deposit druid: #{druid} ***" # useful for debugging

    expect(page).to have_text 'v1 Accessioned'

    # Tests existence of technical metadata
    button = find_button('Technical metadata')
    execute_script('arguments[0].scrollIntoView(true)', button)
    expect(page).to have_text 'Technical metadata'
    click_link_or_button 'Technical metadata'

    sleep(1) # The expansion of TechMD can be slower than the test causing a false failure.
    page.scroll_to(:bottom)

    within('#document-techmd-section') do
      file_listing = find_all('.file')
      # Only preserved files get techmd
      expect(file_listing.size).to eq 2
    end

    # Download Gemfile (preserved=true) from Preservation
    click_link_or_button 'Gemfile'
    expect(page).to have_text 'Preservation:'
    gemfile_pres_link = find('.modal-content a')
    gemfile_pres_url = gemfile_pres_link['href']
    gemfile_pres_link_text = gemfile_pres_link.text
    expect(gemfile_pres_url.end_with?("/items/#{druid}/files/Gemfile/preserved?version=1")).to be true

    puts "about to click on '#{gemfile_pres_link_text}' to get '#{gemfile_pres_url}'"
    click_link_or_button gemfile_pres_link_text
    if page.has_content?('Expected a successful response from the server, but got an error')
      raise 'Error opening opening file modal'
    end

    wait_for_download

    click_link_or_button 'Cancel'

    clear_downloads

    # View Gemfile.lock (shelve=true) from Stacks
    click_link_or_button 'Gemfile.lock'
    expect(page).to have_text 'Stacks:'
    gemfile_lock_stacks_link = find('.modal-content a')
    gemfile_lock_stacks_url = gemfile_lock_stacks_link['href']
    gemfile_lock_stacks_link_text = gemfile_lock_stacks_link.text
    expect(gemfile_lock_stacks_url.end_with?("/file/#{druid}/Gemfile.lock")).to be true

    puts "about to click on '#{gemfile_lock_stacks_link_text}' to get '#{gemfile_lock_stacks_url}'"
    click_link_or_button gemfile_lock_stacks_link_text
    if page.has_content?('Expected a successful response from the server, but got an error')
      raise 'Error opening opening file modal'
    end

    # Return from view of file in browser window to item page
    visit "#{start_url}/view/#{druid}"

    # Check publishing
    expect_published_files(druid:, filenames: ['Gemfile.lock', 'config/settings.yml'])
  end
end
