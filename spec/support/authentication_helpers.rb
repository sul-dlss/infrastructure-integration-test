# frozen_string_literal: true

module AuthenticationHelpers
  mattr_accessor :username, :password

  def authenticate!(start_url:, expected_text:)
    # View the specified starting URL
    visit start_url

    submit_credentials

    using_wait_time 100 do
      # Once we see this we know the log in succeeded.
      expect(page).to have_content expected_text
    end
  end

  def submit_credentials
    self.username ||= username_from_config_or_prompt
    self.password ||= password_from_config_or_prompt

    return unless page.has_content?('SUNet ID')

    # We're at the Stanford login page
    fill_in 'SUNet ID', with: username
    fill_in 'Password', with: password
    sleep 1
    click_button 'Login'

    within_frame('duo_iframe') do
      click_button 'Send Me a Push'
    end
  end

  def ensure_token
    @@token ||= begin
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
