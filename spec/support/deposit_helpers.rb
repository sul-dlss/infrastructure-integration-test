# frozen_string_literal: true

require 'sdr_client'
require 'sdr_client/redesigned_client' # TODO: Update this when the redesigned client is promoted

module DepositHelpers
  # Configure SDR client
  def sdr_client
    @sdr_client ||= SdrClient::RedesignedClient.configure(
      url: Settings.sdrapi_url,
      token: token_refresher.call,
      token_refresher:
    )
  end

  def token_refresher
    proc do
      visit "#{Settings.argo_url}/settings/tokens"
      click_link_or_button 'Generate new token'
      JSON.parse(find_field('Token').value)['token']
    end
  end

  def deposit(**options)
    job_id = sdr_client.build_and_deposit(
      apo: options[:apo] || Settings.default_apo,
      basepath: options[:basepath] || 'spec/fixtures',
      source_id: options[:source_id] || "virtual-object-test:#{SecureRandom.uuid}",
      **options
    )

    job_status = sdr_client.job_status(job_id:)
    job_status.wait_until_complete

    raise 'Did not receive druid from SDR deposit' unless job_status.complete?
    raise job_status.errors.to_s if job_status.errors

    job_status.druid
  end

  # rubocop:disable Metrics/MethodLength
  def deposit_object(filenames: [], label: nil, viewing_direction: nil)
    files_metadata = {}
    grouping_strategy = 'single'
    if filenames.any?
      grouping_strategy = 'filename'
      files_metadata = {
        filenames.first => { 'preserve' => true, 'publish' => false, 'shelve' => false },
        filenames.last => { 'preserve' => false, 'publish' => true, 'shelve' => true }
      }
      file_set_strategy = 'image'
    end

    object_druid = deposit(collection: Settings.default_collection,
                           type: Cocina::Models::ObjectType.image,
                           accession: true,
                           view: 'world',
                           label: label || random_phrase,
                           grouping_strategy:,
                           file_set_strategy:,
                           files: filenames,
                           files_metadata:,
                           viewing_direction:)

    visit "#{start_url}/view/#{object_druid}"

    # Wait for indexing and workflows to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    object_druid
  end
  # rubocop:enable Metrics/MethodLength
end

RSpec.configure { |config| config.include DepositHelpers }
