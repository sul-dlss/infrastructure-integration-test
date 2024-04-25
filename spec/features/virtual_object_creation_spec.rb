# frozen_string_literal: true

RSpec.describe 'Use Argo to create a virtual object with constituent objects' do
  let(:start_url) { Settings.argo_url }
  let(:filename_group) { ['example.tiff', 'example.jp2'] }
  let(:csv_path) { File.join(DownloadHelpers::PATH, 'virtual-object.csv') }
  let(:virtual_objects_description) { random_phrase }
  let(:num_constituents) { Settings.number_of_constituents }

  before do
    authenticate!(start_url:, expected_text: 'Welcome to Argo!')
  end

  scenario do
    # Create virtual object
    virtual_object_label = random_phrase
    virtual_object_druid = deposit_object(label: virtual_object_label, viewing_direction: 'left-to-right')
    puts " *** virtual object druid: #{virtual_object_druid} ***" # useful for debugging

    # Create constituent objects
    constituent_druids = []

    num_constituents.times do
      constituent_druid = deposit_object(filenames: filename_group)
      constituent_druids << constituent_druid
    end

    puts constituent_druids
    puts "   *** constituent object druids: #{constituent_druids.join(', ')} ***" # useful for debugging

    # Create CSV: virtual_object_druid, constituent_druid, constituent_druid
    virtual_object_row = constituent_druids.clone
    virtual_object_row.unshift(virtual_object_druid)

    CSV.open(csv_path, 'w') do |csv|
      csv << virtual_object_row
    end

    # Use Bulk Actions to upload CSV
    click_link_or_button 'Bulk Actions'
    expect(page).to have_text 'Bulk Actions'
    click_link_or_button 'New Bulk Action'
    expect(page).to have_text 'New Bulk Action'
    select 'Create virtual object(s)', from: 'action_type'
    expect(page).to have_text 'Create one or more virtual objects'
    find('input#csv_file').attach_file(csv_path)
    find('textarea#description').fill_in(with: virtual_objects_description)
    click_link_or_button 'Submit'

    expect(page).to have_text 'Create virtual objects job was successfully created.'

    Timeout.timeout(Settings.timeouts.bulk_action) do
      loop do
        page.driver.browser.navigate.refresh

        relevant_bulk_action = find(:xpath, "//tr[td = '#{virtual_objects_description}']")
        within(relevant_bulk_action) do
          status_text = all('td')[3].text
          next unless status_text == 'Completed'

          results_text = all('td')[4].text
          expect(results_text).to eq('1 / 1 / 0')
        end

        break
      end
    end

    visit "#{start_url}/view/#{virtual_object_druid}"
    reload_page_until_timeout!(text: 'v2 Accessioned')

    # Confirm constituent druids are listed in Content
    resources_text = all('.external-file a').map(&:text)

    expect(resources_text).to match_array(constituent_druids)

    # Verify that the purl page of each constituent druid points at the "parent" virtual object purl
    constituent_druids.each do |constituent_druid|
      expect_link_on_purl_page(
        druid: constituent_druid,
        href: "#{Settings.purl_url}/#{virtual_object_druid.delete_prefix('druid:')}",
        text: virtual_object_label
      )
    end
  end
end
