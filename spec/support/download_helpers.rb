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
    Timeout.timeout(TIMEOUT) do
      sleep 0.1 until downloaded?
    end
  end

  def downloaded?
    !downloading? && downloads.any?
  end

  def downloading?
    downloads.grep(/\.crdownload$/).any?
  end

  def clear_downloads
    FileUtils.rm_f(downloads)
  end

  def delete_download(download)
    FileUtils.rm_f(download)
  end
end

RSpec.configure { |config| config.include DownloadHelpers }
