# frozen_string_literal: true

# Helpers for checking objects in Argo-B3
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
end

RSpec.configure { |config| config.include ArgoB3Helpers }
