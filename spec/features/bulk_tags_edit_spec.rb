# frozen_string_literal: true

RSpec.describe 'Use Argo to edit administrative tags in bulk' do
  let(:start_url) { "#{Settings.argo_url}/catalog?f%5Bexploded_nonproject_tag_ssim%5D%5B%5D=Registered+By" }
  let(:export_tag_description) { random_phrase }
  let(:import_tag_description) { random_phrase }
  let(:number_of_druids) { 3 }
  let(:druid_regex) { /^druid:[b-df-hjkmnp-tv-z]{2}[0-9]{3}[b-df-hjkmnp-tv-z]{2}[0-9]{4}/ }
  let(:tag_regex) { /^.+( : .+)+$/ }
  let(:tag_delimiter) { ' : ' }
  let(:upload_csv_path) { File.join(DownloadHelpers::PATH, 'edited.csv') }

  before do
    authenticate!(start_url:, expected_text: 'You searched for:')
  end

  after do
    clear_downloads
  end

  scenario 'exports tags to CSV and then imports them' do
    # Grab top three druids for testing bulk tag operation
    bulk_druids = all('dd.blacklight-id').take(number_of_druids).map(&:text)
    puts " *** bulk tags edit druids: #{bulk_druids.join(', ')} ***" # useful for debugging

    within('.search-widgets') do
      click_link_or_button 'Bulk Actions'
    end
    expect(page).to have_css 'h1', text: 'Bulk Actions'

    click_link_or_button 'New Bulk Action'
    expect(page).to have_text 'New Bulk Action'
    select 'Export tags to CSV', from: 'action_type'
    expect(page).to have_text 'Download tags as CSV (comma-separated values) for druids specified below'
    find('textarea#druids').fill_in(with: bulk_druids.join("\n"))
    find('textarea#description').fill_in(with: export_tag_description)
    click_link_or_button 'Submit'
    expect(page).to have_text 'Export tags job was successfully created.'

    druids_with_tags = []

    # wait for bulk action to complete (runs asynchronously)
    Timeout.timeout(Settings.timeouts.bulk_action) do
      loop do
        page.driver.browser.navigate.refresh

        relevant_bulk_action = find(:xpath, "//tr[td = '#{export_tag_description}']")
        within(relevant_bulk_action) do
          status_text = all('td')[3].text

          next unless status_text == 'Completed'

          results_text = all('td')[4].text
          expect(results_text).to eq("#{number_of_druids} / #{number_of_druids} / 0")

          click_link_or_button 'Download Exported Tags (CSV)'
          wait_for_download
          druids_with_tags = CSV.parse(File.read(download))
          expect(druids_with_tags.count).to eq(number_of_druids)
          druids_with_tags.each do |druid, *tags| # rubocop:disable Style/HashEachMethods rubocop seems mistaken in thinking the tags var is unused
            expect(druid).to match(druid_regex)
            tags.all? { |tag| expect(tag).to match(tag_regex) }
          end
        end

        break
      end
    end

    druid_with_added_tag, druid_with_removed_tag, druid_with_changed_tag = druids_with_tags
    added_tag = random_nouns_array.join(tag_delimiter)

    druid_with_added_tag << added_tag
    removed_tag = druid_with_removed_tag.pop

    replaced_tag = druid_with_changed_tag.pop
    edited_tag = random_nouns_array.join(tag_delimiter)
    druid_with_changed_tag << edited_tag

    CSV.open(upload_csv_path, 'w') do |csv|
      csv << druid_with_added_tag
      csv << druid_with_removed_tag
      csv << druid_with_changed_tag
    end

    click_link_or_button 'New Bulk Action'
    expect(page).to have_text 'New Bulk Action'
    select 'Import tags from CSV', from: 'action_type'
    expect(page).to have_text 'Upload tags as CSV (comma-separated values)'
    find('input#csv_file').attach_file(upload_csv_path)
    find('textarea#description').fill_in(with: import_tag_description)
    click_link_or_button 'Submit'

    expect(page).to have_text 'Import tags job was successfully created.'

    # wait for bulk action to complete (runs asynchronously)
    Timeout.timeout(Settings.timeouts.bulk_action) do
      loop do
        page.driver.browser.navigate.refresh

        relevant_bulk_action = find(:xpath, "//tr[td = '#{import_tag_description}']")
        within(relevant_bulk_action) do
          status_text = all('td')[3].text

          next unless status_text == 'Completed'

          results_text = all('td')[4].text
          expect(results_text).to eq("#{number_of_druids} / #{number_of_druids} / 0")
        end

        break
      end
    end

    visit "#{Settings.argo_url}/view/#{druid_with_added_tag.first}"
    reload_page_until_timeout!(text: added_tag)

    visit "#{Settings.argo_url}/view/#{druid_with_changed_tag.first}"
    reload_page_until_timeout!(text: edited_tag)
    expect(page).to have_no_text(replaced_tag)

    visit "#{Settings.argo_url}/view/#{druid_with_removed_tag.first}"
    expect(page).to have_no_text(removed_tag)
  end
end
