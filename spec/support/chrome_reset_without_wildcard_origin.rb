# frozen_string_literal: true

# Chrome 158 rejects the "*" origin Capybara's reset! uses to clear storage between
# examples, so every Selenium-driven spec fails in teardown with
# "invalid argument: * is not a valid URL". Remove once fixed upstream.
# See https://github.com/teamcapybara/capybara/issues/2865
module ChromeResetWithoutWildcardOrigin
  private

  def execute_cdp(cmd, params = {})
    return super unless cmd == 'Storage.clearDataForOrigin' && params[:origin] == '*'

    super('Network.clearBrowserCookies')
  end
end

Capybara::Selenium::Driver::ChromeDriver.prepend(ChromeResetWithoutWildcardOrigin)
