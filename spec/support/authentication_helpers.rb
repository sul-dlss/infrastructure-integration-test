# frozen_string_literal: true

module AuthenticationHelpers
  mattr_accessor :username, :password, :token

  def authenticate!(start_url:, expected_text:)
    # View the specified starting URL
    visit start_url

    return if page.has_text?(expected_text, wait: Settings.post_authentication_text_timeout)

    submit_credentials

    using_wait_time(Settings.timeouts.capybara) do
      # Once we see this we know the log in succeeded.
      expect(page).to have_text(expected_text)
    end
  end

  def submit_credentials
    self.username ||= username_from_config_or_prompt
    self.password ||= password_from_config_or_prompt

    if page.has_text?('SUNet ID', wait: Settings.post_authentication_text_timeout)
      fill_in 'SUNet ID', with: username
      fill_in 'Password', with: password
      click_button 'Login'
    end

    click_button 'Yes, trust browser'
  end

  def ensure_token
    self.token ||= begin
      visit "#{Settings.argo_url}/settings/tokens"
      click_button 'Generate new token'
      find_field('Token').value.tap do |token|
        SdrClient::Credentials.write(token)
      end
    end
  end

  private

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
end
