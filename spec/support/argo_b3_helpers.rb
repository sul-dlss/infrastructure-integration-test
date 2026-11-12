# frozen_string_literal: true

require 'tempfile'

# Helpers for registering, depositing, and checking objects in Argo-B3
module ArgoB3Helpers
  def expect_files_on_object_page(druid:, filenames:, absent_filenames: [])
    visit "#{Settings.argo_b3_url}/objects/#{druid}"
    expect(page).to have_css('h2', text: 'Deposited')
    find_by_id('files-tab').click
    within('#files-pane') do
      filenames.each { |filename| expect(page).to have_css('tbody th', exact_text: filename) }
      absent_filenames.each { |filename| expect(page).to have_no_css('tbody th', exact_text: filename) }
    end
  end

  # @param files [Hash<String, Hash>] keyed by filename, with :size (Regexp), :mime_type, and optional :role
  def expect_file_details_on_object_page(druid:, files:)
    visit "#{Settings.argo_b3_url}/objects/#{druid}"
    find_by_id('files-tab').click
    within('#files-pane') do
      # The technical metadata rows are hidden, so are not counted.
      expect(page).to have_css('tbody tr', count: files.size)
      files.each do |filename, file|
        # Found by the row header, since a row's toggle button also names the file (in visually hidden text).
        row = find(:xpath, ".//tbody/tr[th[normalize-space()='#{filename}']]")
        expect(row).to have_text(/#{Regexp.escape(filename)}\s+#{file[:size]}\s+#{Regexp.escape(file[:mime_type])}/)
      end
    end

    # Roles are only shown on the Structure tab.
    find_by_id('structure-tab').click
    within('#structure-pane') do
      files.each do |filename, file|
        next unless file[:role]

        row = find('tbody tr', text: /\A#{Regexp.escape(filename)}\s/)
        expect(row.all('td')[6]).to have_text(file[:role])
      end
    end
  end

  # Reads the druids from the registration report of the current bulk action page.
  # @return [Hash<String, String>] druids keyed by source ID
  def registered_druids(source_ids:)
    # The bulk action page refreshes itself until it is complete, when it shows the registration report.
    report_table = find_by_id('bulk-action-registration-report-table', wait: Settings.timeouts.bulk_action)
    source_ids.to_h do |source_id|
      # The first column is the bare druid.
      [source_id, "druid:#{report_table.find('tr', text: source_id).first('td').text.strip}"]
    end
  end

  # @param folders [Hash<String, Hash>] keyed by druid, with the :folder on the mount and expected :file_count
  # @param deposit_type [String] new item or redeposit
  # @param version_description [String] only for redeposits, since it is fixed for new items
  def deposit_multiple_items(description:, mount_path:, folders:, deposit_type:, version_description: nil)
    visit Settings.argo_b3_url
    click_button 'Deposit multiple items'
    expect(page).to have_css('h1', text: 'Multi-item deposit')

    discover_files(description:, mount_path:, folders:)
    check_files(folders:, deposit_type:)
    start_deposit(druids: folders.keys, version_description:)
  end

  private

  def discover_files(description:, mount_path:, folders:)
    fill_in 'Describe this deposit', with: description
    Tempfile.create(['argo_b3_manifest', '.csv']) do |manifest|
      manifest.write(CSV.generate do |csv|
        csv << %w[druid folder]
        folders.each { |druid, folder| csv << [druid, folder[:folder]] }
      end)
      manifest.close
      attach_file('Upload manifest file', manifest.path)
      choose 'Select files from mount'
      fill_in 'Mount path', with: mount_path
      click_button 'Discover files and check manifest'
      # The page refreshes itself until discovery is complete.
      expect(page).to have_text('No errors with manifest', wait: Settings.timeouts.bulk_action)
    end
    click_button 'Next'
  end

  def check_files(folders:, deposit_type:)
    choose 'Publish and preserve all files'
    click_button 'Check files'
    expect(page).to have_css('h2', text: 'Results of checking files', wait: Settings.timeouts.bulk_action)
    folders.each do |druid, folder|
      expect(page).to have_css(
        'tr',
        text: /#{bare_druid(druid)}\s+#{Regexp.escape(folder[:folder])}\s+#{folder[:file_count]}\s+OK\s+.+\s+#{deposit_type}/
      )
    end
    click_button 'Next'
  end

  def start_deposit(druids:, version_description:)
    fill_in 'Version description', with: version_description if version_description
    click_button 'Check version status and deposit'
    expect(page).to have_css('h2', text: 'Deposit status', wait: Settings.timeouts.bulk_action)
    # The page refreshes itself as the deposits progress.
    druids.each do |druid|
      expect(page).to have_css('tbody tr', text: /#{bare_druid(druid)}\s+Deposited/, wait: Settings.timeouts.workflow)
    end
  end
end

RSpec.configure { |config| config.include ArgoB3Helpers }
