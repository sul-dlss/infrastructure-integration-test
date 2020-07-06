# frozen_string_literal: true

RSpec.describe 'Use Argo to edit administrative tags in bulk', type: :feature do
  let(:start_url) { 'https://argo-stage.stanford.edu/catalog?f%5Bexploded_tag_ssim%5D%5B%5D=Registered+By' }
  let(:export_tag_description) { RandomWord.phrases.next }
  let(:import_tag_description) { RandomWord.phrases.next }
  let(:number_of_druids) { 3 }
  let(:druid_regex) { /^druid:[b-df-hjkmnp-tv-z]{2}[0-9]{3}[b-df-hjkmnp-tv-z]{2}[0-9]{4}/ }
  let(:tag_regex) { /^.+( : .+)+$/ }
  let(:tag_delimiter) { ' : ' }
  let(:upload_csv_path) { File.join(DownloadHelpers::PATH, 'edited.csv') }

  before do
    authenticate!(start_url: start_url, expected_text: 'You searched for:')
  end

  after do
    clear_downloads
  end

  scenario 'exports tags to CSV and then imports them' do
    # Grab top three druids for testing bulk tag operation
    bulk_druids = all('dd.blacklight-id').take(number_of_druids).map(&:text)

    click_link 'Bulk Edits'
    click_link 'Bulk Actions (asynchronous)'
    expect(page).to have_content 'Bulk Actions'

    click_link 'New Bulk Action'
    expect(page).to have_content 'New Bulk Action'
    select 'Export tags to CSV', from: 'bulk_action_action_type'
    expect(page).to have_content 'Download tags as CSV (comma-separated values) for druids specified below'
    find('textarea#pids').fill_in(with: bulk_druids.join("\n"))
    find('textarea#bulk_action_description').fill_in(with: export_tag_description)
    click_button 'Submit'

    expect(page).to have_content 'Bulk action was successfully created.'

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

          click_link 'Download Exported Tags (CSV)'
          wait_for_download

          druids_with_tags = CSV.parse(File.read(download))
          expect(druids_with_tags.count).to eq(number_of_druids)
          druids_with_tags.each do |druid, *tags|
            expect(druid).to match(druid_regex)
            tags.all? { |tag| expect(tag).to match(tag_regex) }
          end
        end

        break
      end
    end

    druid_with_added_tag, druid_with_removed_tag, druid_with_changed_tag = druids_with_tags
    added_tag = RandomWord.nouns.take(3).join(tag_delimiter)

    druid_with_added_tag << added_tag
    removed_tag = druid_with_removed_tag.pop

    replaced_tag = druid_with_changed_tag.pop
    edited_tag = RandomWord.nouns.take(3).join(tag_delimiter)
    druid_with_changed_tag << edited_tag

    CSV.open(upload_csv_path, 'w') do |csv|
      csv << druid_with_added_tag
      csv << druid_with_removed_tag
      csv << druid_with_changed_tag
    end

    click_link 'New Bulk Action'
    expect(page).to have_content 'New Bulk Action'
    select 'Import tags from CSV', from: 'bulk_action_action_type'
    expect(page).to have_content 'Upload tags as CSV (comma-separated values)'
    find('input#bulk_action_import_tags_csv_file').attach_file(upload_csv_path)
    find('textarea#bulk_action_description').fill_in(with: import_tag_description)
    click_button 'Submit'

    expect(page).to have_content 'Bulk action was successfully created.'

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

    visit "https://argo-stage.stanford.edu/view/#{druid_with_added_tag.first}"
    expect(page).to have_content(added_tag)

    visit "https://argo-stage.stanford.edu/view/#{druid_with_removed_tag.first}"
    expect(page).not_to have_content(removed_tag)

    visit "https://argo-stage.stanford.edu/view/#{druid_with_changed_tag.first}"
    expect(page).to have_content(edited_tag)
    expect(page).not_to have_content(replaced_tag)
  end
end
