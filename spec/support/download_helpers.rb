# frozen_string_literal: true

module DownloadHelpers
  TIMEOUT = 10
  PATH    = Pathname.new(File.expand_path('../../downloads', __dir__))

  module_function

  def downloads
    Dir[PATH.join('*')]
  end

  def download
    downloads.delete_if { |path| /Argo_files\z/.match?(path) }.first
  end

  def download_content
    wait_for_download
    File.read(download)
  end

  def wait_for_download
    # raising StandardError with a helpful message makes failure reporting nicer
    Timeout.timeout(TIMEOUT, StandardError, 'timed out waiting for download') do
      sleep 0.1 until downloaded?
    end
    # wait a bit longer to ensure the download is complete
    sleep 0.5
  end

  def downloaded?
    !downloading? && downloads.any?
  end

  def downloading?
    downloads.grep(/\.crdownload$/).any?
  end

  def clear_downloads
    return unless downloads.any?

    begin
      FileUtils.rm_f(downloads)
      puts "Cleared #{downloads.length} download files" if downloads.any?
    rescue => e
      puts "Warning: Could not clear all downloads: #{e.message}"
    end
  end

  def delete_download(download)
    return unless download && File.exist?(download)

    begin
      FileUtils.rm_f(download)
      puts "Deleted download file: #{File.basename(download)}"
    rescue => e
      puts "Warning: Could not delete download #{download}: #{e.message}"
    end
  end
end

RSpec.configure do |config|
  config.include DownloadHelpers

  # Automatically clear downloads after each test for better isolation
  config.after(:each) do
    clear_downloads if respond_to?(:clear_downloads)
  end
end
