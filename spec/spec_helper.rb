# frozen_string_literal: true

require 'config'
require 'csv'
require 'debug'
require 'faker'
require 'io/console'
require 'rubyXL'
require 'sdr_client'
require 'selenium-webdriver'

$sdr_env = ENV.fetch('SDR_ENV', 'stage')
root = Pathname.new(File.expand_path('../', __dir__))

# Setup Config gem before loading spec supports
Config.setup do |config|
  config.const_name = 'Settings'
  config.use_env = true
  config.env_prefix = 'SETTINGS'
  config.env_separator = '__'
  config.env_converter = :downcase
end

Config.load_and_set_settings(
  Config.setting_files(root.join('config'), $sdr_env)
)

# NOTE: Added to flag situations where the wrong env is typed, e.g., `stage`
unless Settings.supported_envs.include?($sdr_env)
  raise "#{$sdr_env} is not a supported environment: #{Settings.supported_envs.join(', ')}"
end

Dir[root.join('spec', 'support', '**', '*.rb')].each { |f| require f }

# See http://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.include Capybara::DSL # required without `type: :feature` spec metadata, which RSpec infers

  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  # rspec-mocks config goes here. You can use an alternate test double
  # library (such as bogus or mocha) by changing the `mock_with` option here.
  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does not exist on
    # a real object. This is generally recommended, and will default to
    # `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # When a test fails, try to take a screenshot of the page right after the failure, and print the URL where the failure occurred
  #
  # Cribbed from https://gist.github.com/osulyanov/10609515 and https://rspec.info/documentation/3.13/rspec-core/RSpec/Core/Example.html
  # We may have used this gem in the past, but it had no commits in 4 years as of feb 2025: https://github.com/mattheworiordan/capybara-screenshot
  config.after do |example|
    if example.exception.present?
      filename = File.basename(example.file_path).sub(/.rb$/, '') # /foo/bar.rb -> bar
      line_number = example.location.match(/:(\d+)$/)&.match(1) # ./path/to/spec.rb:17 -> 17
      screenshot_name = "failure-auto-screenshot-#{DateTime.now.strftime('%Y%m%d-%H%M%S')}-#{filename}-#{line_number}.png"
      screenshot_path = "tmp/#{screenshot_name}"

      page.save_screenshot(screenshot_path) # rubocop:disable Lint/Debugger

      puts "📸 '#{example.full_description}' failed (url: '#{page.current_url}'). Screenshot: #{screenshot_path}"
    end
  rescue StandardError => e
    puts "⚠️ error taking screenshot for failed test: #{e}"
  end

  # This option will default to `:apply_to_host_groups` in RSpec 4 (and will
  # have no way to turn it off -- the option exists only for backwards
  # compatibility in RSpec 3). It causes shared context metadata to be
  # inherited by the metadata hash of host groups and examples, rather than
  # triggering implicit auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # The settings below are suggested to provide a good initial experience
  # with RSpec, but feel free to customize to your heart's content.
  # This allows you to limit a spec run to individual examples or groups
  # you care about by tagging them with `:focus` metadata. When nothing
  # is tagged with `:focus`, all examples get run. RSpec also provides
  # aliases for `it`, `describe`, and `context` that include `:focus`
  # metadata: `fit`, `fdescribe` and `fcontext`, respectively.
  config.filter_run_when_matching :focus

  # Allows RSpec to persist some state between runs in order to support
  # the `--only-failures` and `--next-failure` CLI options. We recommend
  # you configure your source control system to ignore this file.
  config.example_status_persistence_file_path = 'spec/examples.txt'

  # Limits the available syntax to the non-monkey patched syntax that is
  # recommended. For more details, see:
  #   - http://rspec.info/blog/2012/06/rspecs-new-expectation-syntax/
  #   - http://www.teaisaweso.me/blog/2013/05/27/rspecs-new-message-expectation-syntax/
  #   - http://rspec.info/blog/2014/05/notable-changes-in-rspec-3/#zero-monkey-patching-mode
  config.disable_monkey_patching!

  # This setting enables warnings. It's recommended, but in some cases may
  # be too noisy due to issues in dependencies.
  # config.warnings = true

  # Many RSpec users commonly either run the entire suite or an individual
  # file, and it's useful to allow more verbose output when running an
  # individual spec file.
  if config.files_to_run.one?
    # Use the documentation formatter for detailed output,
    # unless a formatter has already been configured
    # (e.g. via a command-line flag).
    config.default_formatter = 'doc'
  end

  # Print the 10 slowest examples and example groups at the
  # end of the spec run, to help surface which specs are running
  # particularly slow.
  # config.profile_examples = 10

  # Run specs in random order to surface order dependencies. If you find an
  # order dependency and want to debug it, you can fix the order by providing
  # the seed, which is printed after each run.
  #     --seed 1234
  config.order = :random

  # Seed global randomization in this process using the `--seed` CLI option.
  # Setting this allows you to use `--seed` to deterministically reproduce
  # test failures related to randomization by passing the same `--seed` value
  # as the one that triggered the failure.
  Kernel.srand config.seed
end
