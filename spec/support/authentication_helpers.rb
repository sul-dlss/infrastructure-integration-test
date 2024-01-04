# frozen_string_literal: true

module AuthenticationHelpers
  mattr_accessor :username, :password, :token

  def authenticate!(start_url:, expected_text:)
    ensure_username! # sunet is needed by some tests, even if the user doesn't have to enter user/pass for Stanford web authN

    # View the specified starting URL
    visit start_url
    return if expected_text_found?(expected_text) # short-circuit if we are already authenticated

    # cardinal key users go straight to 2FA prompts without login form
    click_through_check_if_needed('Yes, trust browser')
    click_through_check_if_needed('Yes, this is my device')

    # non-cardinal key users get login form followed by 2FA prompts
    submit_credentials_if_needed
    click_through_check_if_needed('Yes, trust browser')
    click_through_check_if_needed('Yes, this is my device')

    expected_text_found?(expected_text)
  end

  def ensure_token
    self.token ||= begin
      visit "#{Settings.argo_url}/settings/tokens"
      click_link_or_button 'Generate new token'
      find_field('Token').value.tap do |token|
        SdrClient::Credentials.write(token)
      end
    end
  end

  private

  def expected_text_found?(expected_text)
    if page.has_text?(expected_text, wait: Settings.timeouts.post_authentication_text)
      puts " > logged in, found expected post-login String/Regex: #{expected_text}"
      true
    else
      puts " ! WARNING: logged in, but no match for expected post-login String/Regex: #{expected_text}"
      false
    end
  end

  def username_from_config_or_prompt
    Settings.sunet.id || begin
      print 'SUNet ID: '
      username = $stdin.gets
      username.strip
    end
  end

  def password_from_config_or_prompt
    Settings.sunet.password || begin
      print 'Password: '
      password = $stdin.noecho(&:gets)
      # So the user knows we're off the password prompt
      puts
      password.strip
    end
  end

  def ensure_username!
    self.username ||= username_from_config_or_prompt
  end

  def ensure_password!
    self.password ||= password_from_config_or_prompt
  end

  def submit_credentials_if_needed
    return unless page.has_text?('SUNet ID', wait: Settings.timeouts.post_authentication_text)

    ensure_password!
    fill_in 'SUNet ID', with: username
    fill_in 'Password', with: password
    click_link_or_button 'Login'
  end

  def click_through_check_if_needed(text)
    return unless page.has_text?(text, wait: Settings.timeouts.post_authentication_text)

    click_link_or_button text
  end
end

RSpec.configure { |config| config.include AuthenticationHelpers }
