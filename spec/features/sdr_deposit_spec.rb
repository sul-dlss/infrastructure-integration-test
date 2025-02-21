# frozen_string_literal: true

RSpec.describe 'SDR deposit' do
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

    visit "#{start_url}/view/#{druid}"

    # Wait for indexing and workflows to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    expect(page).to have_text 'The means to prosperity'

    # Tests existence of technical metadata
    expect(page).to have_text 'Technical metadata'
    click_link_or_button 'Technical metadata'

    # this is a hack that forces the techMD section to scroll into view; the section
    # is lazily loaded, and won't actually be requested otherwise, even if the button
    # is clicked to expand the technical metadata section.
    page.execute_script 'window.scrollBy(0,100);'

    within('#document-techmd-section') do
      file_listing = find_all('.file')
      # Only preserved files get techmd
      expect(file_listing.size).to eq 2
    end

    # Wait for accessioningWF to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    # We think this is needed due to network file system lag (between write to disk finishing, and
    # initial visibility to client VMs).  waiting briefly usually works, so retry for a bit.
    retries_count = 0
    begin
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
    rescue StandardError => e
      puts "download attempt failed (link click text=#{gemfile_pres_link_text}): #{e.class}; #{e.inspect}; #{e}"

      puts "sleeping and retrying (retries_count=#{retries_count})"
      sleep 10
      retries_count += 1
      if retries_count < 5
        visit "#{start_url}/view/#{druid}"
        retry
      end
    end
    wait_for_download

    click_link_or_button 'Cancel'

    # We think this is needed due to network file system lag (between write to disk finishing, and
    # initial visibility to client VMs).  waiting briefly usually works, so retry for a bit.
    retries_count = 0
    begin
      # Download Gemfile.lock (shelve=true) from Stacks
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
    rescue StandardError => e
      puts "download attempt failed (link click text=#{gemfile_lock_stacks_link_text}): #{e.class}; #{e.inspect}; #{e}"

      puts "sleeping and retrying (retries_count=#{retries_count})"
      sleep 10
      retries_count += 1
      if retries_count < 5
        visit "#{start_url}/view/#{druid}"
        retry
      end
    end
    wait_for_download

    click_link_or_button 'Cancel'

    clear_downloads

    # Try to download Gemfile.lock (preserve=false) from Preservation
    click_link_or_button 'Gemfile'
    expect(page).to have_text 'Preservation:'
    # Visit doesn't work here, so https://tenor.com/view/sneaky-sis-connect-four-commercial-hero-gif-12265444
    page.execute_script "document.querySelector('.modal-content a').href = '#{gemfile_pres_url.sub('Gemfile',
                                                                                                   'Gemfile.lock')}'"
    gemfile_pres_link = find('.modal-content a')
    gemfile_pres_link_text = gemfile_pres_link.text
    expect(gemfile_pres_link['href'].end_with?("/items/#{druid}/files/Gemfile.lock/preserved?version=1")).to be true

    puts "about to click on '#{gemfile_pres_link_text}' to get '#{gemfile_pres_url}'"
    download_error = nil
    begin
      click_link_or_button gemfile_pres_link.text
    rescue Selenium::WebDriver::Error::WebDriverError => e
      puts "download attempt failed (link click text=#{gemfile_pres_link_text}): #{e.class}; #{e.inspect}; #{e}"
      download_error = e
    end

    # We've seen both of these behaviors on different runs against the same deployment
    if download_error.present?
      # selenium-webdriver doesn't expose response info, so here's a workaround for detecting 404 behavior
      expect(download_error.to_s).to include('Reached error page: about:neterror?e=fileNotFound')
      visit "#{start_url}/view/#{druid}"
    else
      # This file is downloaded, but contains a 404 error message.
      expect(download_content).to include '404 Not Found'
      click_link_or_button 'Cancel'
    end

    # Try to download Gemfile (shelve=false) from Stacks
    click_link_or_button 'Gemfile.lock'
    expect(page).to have_text 'Stacks:'
    page.execute_script "document.querySelector('.modal-content a').href = " \
                        "'#{gemfile_lock_stacks_url.delete_suffix('.lock')}'"
    gemfile_stacks_link = find('.modal-content a')
    expect(gemfile_stacks_link['href'].end_with?("/file/#{druid}/Gemfile")).to be true

    click_link_or_button gemfile_stacks_link.text
    expect(page).to have_text 'File not found'

    # Check publishing
    expect_published_files(druid:, filenames: ['Gemfile.lock', 'config/settings.yml'])
  end
end
