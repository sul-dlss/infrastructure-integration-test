# frozen_string_literal: true

# This module allows us to check the purl page for a given string
module PurlHelpers
  def visit_purl_page(druid)
    visit "#{Settings.purl_url}/#{bare_druid(druid)}"
    expect(page).to have_css('body') # wait for page to load
  end

  def expect_text_on_purl_page(druid:, text:, within_frame: false)
    visit_purl_page(druid)
    if within_frame
      reload_page_until_timeout! do
        within_frame { page.has_text?(text, wait: 2) }
      end
    else
      reload_page_until_timeout!(text:)
    end
  end

  def do_not_expect_text_on_purl_page(druid:, text:) # rubocop:disable Naming/PredicateMethod
    visit_purl_page(druid)
    page.has_no_text?(text)
  end

  def expect_link_on_purl_page(druid:, text:, href:)
    visit_purl_page(druid)
    reload_page_until_timeout! { page.has_link?(text, href:, wait: 2) }
  end

  def expect_published_files(druid:, filenames:)
    cocina_json = JSON.parse(Faraday.get("#{Settings.purl_url}/#{druid.delete_prefix('druid:')}.json").body)
    check_filenames = cocina_json['structural']['contains'].map { |node| node['structural']['contains'].first['filename'] }
    expect(check_filenames).to eq filenames
  end

  def bare_druid(druid)
    druid.delete_prefix('druid:')
  end
end

RSpec.configure { |config| config.include PurlHelpers }
