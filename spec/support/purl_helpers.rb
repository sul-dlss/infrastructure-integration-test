# frozen_string_literal: true

# This module allows us to check the purl page for a given string
module PurlHelpers
  def expect_text_on_purl_page(druid:, text:, within_frame: false)
    bare_druid = druid.delete_prefix('druid:')
    visit "#{Settings.purl_url}/#{bare_druid}"
    if within_frame
      reload_page_until_timeout! do
        within_frame { page.has_text?(text, wait: 2) }
      end
    else
      reload_page_until_timeout!(text:)
    end
  end

  def expect_link_on_purl_page(druid:, text:, href:)
    bare_druid = druid.delete_prefix('druid:')
    visit "#{Settings.purl_url}/#{bare_druid}"
    reload_page_until_timeout! { page.has_link?(text, href:, wait: 2) }
  end
end

RSpec.configure { |config| config.include PurlHelpers }
