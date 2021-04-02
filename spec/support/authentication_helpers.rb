# frozen_string_literal: true

module AuthenticationHelpers
  mattr_accessor :username, :password

  def authenticate!(start_url:, expected_text:)
    # View the specified starting URL
    visit start_url

    submit_credentials(expected_text)

    using_wait_time 100 do
      # Once we see this we know the log in succeeded.
      expect(page).to have_content expected_text
    end
  end

  # rubocop:disable Metrics/AbcSize
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/PerceivedComplexity
  def submit_credentials(expected_text = '')
    self.username ||= username_from_config_or_prompt
    self.password ||= password_from_config_or_prompt

    return unless page.has_content?('SUNet ID')

    # We're at the Stanford login page
    fill_in 'SUNet ID', with: username
    fill_in 'Password', with: password
    sleep 1
    click_button 'Login'

    if Settings.automatic_authentication
      # did we already get authenticated?
      return if expected_text.present? && page.has_text?(expected_text, wait: Settings.post_authentication_text_timeout)

      # did we already push, but not authenticated?
      begin
        page.has_text?('Pushed a login request to your device', wait: Settings.post_authentication_text_timeout)
      rescue Capybara::ElementNotFound
        # the app uses an explicit push
        within_frame('duo_iframe') do
          click_button 'Send Me a Push'
        end
      end
    else
      within_frame('duo_iframe') do
        click_button 'Send Me a Push'
      end
    end
  end
  # rubocop:enable Metrics/AbcSize
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/PerceivedComplexity

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
