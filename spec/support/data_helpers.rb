# frozen_string_literal: true

require 'yaml'
require 'fileutils'
require 'date'

# DataHelpers provides thread-safe read/write of druid and test data to a daily YAML file.
#
# The file is written to ./tmp/{YYYY-MM-DD}_data.yml with string keys.
# Value is a Hash for multi-value specs, or a plain String for single-druid specs.
#
# Usage in submit spec:
#   save_test_data(spec_name: 'collection_creation', data: { 'druid' => collection_druid, 'title' => collection_title })
#
# Usage in review spec:
#   data = load_test_data(spec_name: 'collection_creation')
#   collection_druid = data['druid']
module DataHelpers
  DATA_MUTEX = Mutex.new
  TMP_DIR = File.expand_path('../../tmp', __dir__) # resolves to project-root/tmp/

  # Write (merge) test data for a spec into today's YAML file.
  # @param spec_name [String] key to store under, e.g. 'collection_creation'
  # @param data [Hash, String] Hash for multi-value specs, bare druid String for single-druid specs
  def save_test_data(spec_name:, data:)
    FileUtils.mkdir_p(TMP_DIR)
    DATA_MUTEX.synchronize do
      file_path = today_data_file_path
      existing = load_yaml_file(file_path)
      existing[spec_name] = data
      File.write(file_path, existing.to_yaml)
      puts " *** DataHelpers: saved '#{spec_name}' → #{file_path} ***"
    end
  end

  # Load test data for a spec. Prefers today's file; falls back to most-recent file in tmp/.
  # Raises with a helpful message if the file or key is missing.
  # @param spec_name [String] key to look up
  # @return [Hash, String] the stored data
  def load_test_data(spec_name:)
    file_path = most_recent_data_file_path
    raise "DataHelpers: no data file found in #{TMP_DIR}. Did submit specs run first?" unless file_path

    data = load_yaml_file(file_path)
    result = data[spec_name]
    raise "DataHelpers: no entry for '#{spec_name}' in #{file_path}. Did the submit spec pass?" unless result

    puts " *** DataHelpers: loaded '#{spec_name}' from #{file_path} ***"
    result
  end

  private

  def today_data_file_path
    File.join(TMP_DIR, "#{Date.today.strftime('%Y-%m-%d')}_data.yml")
  end

  def most_recent_data_file_path
    today = today_data_file_path
    return today if File.exist?(today)

    Dir[File.join(TMP_DIR, '*_data.yml')].last
  end

  def load_yaml_file(file_path)
    return {} unless File.exist?(file_path)

    YAML.safe_load_file(file_path, permitted_classes: [Symbol], symbolize_names: false) || {}
  end
end

RSpec.configure { |config| config.include DataHelpers }
