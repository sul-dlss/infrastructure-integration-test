# frozen_string_literal: true

require 'active_support'
require 'active_support/core_ext/array/conversions' # for `Array#to_sentence`

RSpec.describe 'Use Argo to edit administrative tags in bulk', type: :feature do
  let(:start_url) { 'https://argo-stage.stanford.edu/catalog?f%5Bexploded_tag_ssim%5D%5B%5D=Registered+By' }

  before do
    authenticate!(start_url: start_url, expected_text: 'You searched for:')
  end

  scenario do
    # Grab top three druids for testing bulk tag operation
    bulk_druids = all('dd.blacklight-id').take(3).map(&:text)
    tags = [
      RandomWord.nouns.take(3).join(' : '),
      RandomWord.nouns.take(3).join(' : '),
      RandomWord.nouns.take(3).join(' : ')
    ]
    druids_with_tags = bulk_druids.map { |druid| "#{druid}\t#{tags.join("\t")}" }.join("\n")

    click_link 'Bulk Edits'
    click_link 'Bulk Update (synchronous)'

    expect(page).to have_content 'Bulk update operations'
    find('span#paste-druids-button').click
    expect(page).to have_content 'Bulk actions will be performed on this list of druids'
    find('textarea#pids').fill_in(with: bulk_druids.join("\n"))
    click_button 'Tags'
    expect(page).to have_content 'Change tags'
    find('textarea#tags').fill_in(with: druids_with_tags)
    find('span#set_tags').click
    expect(page).to have_content 'Done!'
    expect(page).to have_content "Using #{bulk_druids.count} user supplied druids and tags"
    expect(page).not_to have_content(/error/i)
  end
end
