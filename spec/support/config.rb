# frozen_string_literal: true

require 'config'

# NOTE: For some reason `File.expand_path(__dir__, '../..')` did not do the right thing.
app_root = Pathname.new(__dir__).parent.parent
config_root = app_root.join('config')
env = ENV.fetch('SDR_ENV', 'staging')

Config.load_and_set_settings(
  Config.setting_files(config_root, env)
)

# NOTE: Added to flag situations where the wrong env is typed, e.g., `stage`
unless Settings.supported_envs.include?(env)
  raise "#{env} is not a supported environment: #{Settings.supported_envs.join(', ')}"
end
