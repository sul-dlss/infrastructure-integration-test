# frozen_string_literal: true

require 'capybara/rspec'
require 'capybara_table/rspec'

# Silence deprecation warnings until upstream Capybara version is updated.
# See: https://github.com/teamcapybara/capybara/issues/2779
Selenium::WebDriver.logger.ignore(:clear_local_storage, :clear_session_storage)

Capybara.enable_aria_label = true

Capybara.run_server = false

Capybara.register_driver :my_firefox_driver do |app|
  silence_warnings do
    Selenium::WebDriver::Firefox::Service::EXECUTABLE = Settings.browser.geckodriver_path if Settings.browser.geckodriver_path
  end

  options = Selenium::WebDriver::Firefox::Options.new
  options.profile = Selenium::WebDriver::Firefox::Profile.new.tap do |profile|
    profile['browser.download.alwaysOpenPanel'] = false
    profile['browser.download.dir'] = DownloadHelpers::PATH.to_s
    # profile["browser.helperApps.neverAsk.openFile"] = "application/x-yaml"
    profile['browser.download.folderList'] = 2
    profile['browser.helperApps.neverAsk.saveToDisk'] = 'application/x-yaml;text/csv'
    # these two have been proven to be needed to prevent cardinalkey from
    # constantly prompting to confirm certificate
    # https://uit.stanford.edu/service/cardinalkey/known-issues
    profile['security.default_personal_cert'] = 'Select Automatically'
    profile['security.enterprise_roots.enabled'] = 'true'
  end
  # NOTE: You might think the `--window-size` arg would work here. Not for me, it didn't.
  options.add_argument("--width=#{Settings.browser.width}")
  options.add_argument("--height=#{Settings.browser.height}")
  options.binary = Settings.browser.firefox_path if Settings.browser.firefox_path

  Capybara::Selenium::Driver.new(app, browser: :firefox, options:)
end

Capybara.register_driver :my_chrome_driver do |app|
  options = Selenium::WebDriver::Chrome::Options.new(
    args: ["window-size=#{Settings.browser.width},#{Settings.browser.height}"]
  )

  Capybara::Selenium::Driver.new(app, browser: :chrome, options:).tap do |driver|
    driver.browser.download_path = DownloadHelpers::PATH.to_s
  end
end

Capybara.default_driver = case Settings.browser.driver
                          when 'chrome'
                            :my_chrome_driver
                          else
                            :my_firefox_driver
                          end

Capybara.default_max_wait_time = Settings.timeouts.capybara

RSpec.configure do |config|
  # This will output the browser console logs after each feature test
  config.after(:each, type: :feature) do |_example|
    Rails.logger.info('Browser log entries from feature spec run include:')
    Capybara.page.driver.browser.logs.get(:browser).each do |log_entry|
      Rails.logger.info("* #{log_entry}")
    end
  end
end
