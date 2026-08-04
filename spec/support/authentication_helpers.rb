# frozen_string_literal: true

module AuthenticationHelpers
  # Cached credentials - set once per suite run, read-only after that.
  # Using module instance variables (not class-level attr_accessor)
  # to prevent accidental mutation from test code.
  @username = nil
  @password = nil

  class << self
    def username
      @username ||= Settings.sunet.id || prompt_for('SUNet ID')
    end

    def password
      @password ||= Settings.sunet.password || prompt_for_password
    end

    private

    def prompt_for(label)
      print "#{label}: "
      $stdin.gets.strip
    end

    def prompt_for_password
      print 'Password: '
      password = $stdin.noecho(&:gets)
      puts
      password.strip
    end
  end

  def authenticate!(start_url:, expected_text:)
    # Ensure username is resolved (needed by some tests even without login form)
    AuthenticationHelpers.username

    visit start_url
    return if expected_text_found?(expected_text)

    # cardinal key users go straight to 2FA prompts without login form
    click_through_check_if_needed('Yes, trust browser')
    click_through_check_if_needed('Yes, this is my device')

    # non-cardinal key users get login form followed by 2FA prompts
    submit_credentials_if_needed
    click_through_check_if_needed('Yes, trust browser')
    click_through_check_if_needed('Yes, this is my device')

    expected_text_found?(expected_text)
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

  def submit_credentials_if_needed
    return unless page.has_text?('SUNet ID', wait: Settings.timeouts.post_authentication_text)

    fill_in 'SUNet ID', with: AuthenticationHelpers.username
    fill_in 'Password', with: AuthenticationHelpers.password
    click_link_or_button 'Login'
  end

  def click_through_check_if_needed(text)
    return unless page.has_text?(text, wait: Settings.timeouts.post_authentication_text)

    click_link_or_button text
  end
end

RSpec.configure { |config| config.include AuthenticationHelpers }
