# frozen_string_literal: true

# This module allows us to check the purl page for a given string
module PurlHelpers
  def expect_text_on_purl_page(druid:, text:, within_frame: false)
    visit "#{Settings.purl_url}/#{bare_druid(druid)}"
    sleep 1
    if within_frame
      reload_page_until_timeout! do
        within_frame { page.has_text?(text, wait: 2) }
      end
    else
      reload_page_until_timeout!(text:)
    end
  end

  def do_not_expect_text_on_purl_page(druid:, text:) # rubocop:disable Naming/PredicateMethod
    visit "#{Settings.purl_url}/#{bare_druid(druid)}"
    sleep 1
    page.has_no_text?(text)
  end

  def expect_link_on_purl_page(druid:, text:, href:)
    visit "#{Settings.purl_url}/#{bare_druid(druid)}"
    sleep 1
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

  # The image derivative can take a minute or so to become available after the IIIF manifest is published,
  # so retry a few times before giving up.
  def fetch_image_response(image_url, attempts: 6, wait_seconds: 10)
    attempts.times do |attempt|
      response = Faraday.get(image_url)
      return response if response.status == 200

      puts "Image not yet accessible at #{image_url} (attempt #{attempt + 1}/#{attempts}), waiting #{wait_seconds}s..."
      sleep wait_seconds
    end
    Faraday.get(image_url)
  end
end

RSpec.configure { |config| config.include PurlHelpers }
