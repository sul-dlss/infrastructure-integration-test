# frozen_string_literal: true

module DepositHelpers
  def deposit(**kwargs)
    job_id = SdrClient::Deposit.run(**kwargs)

    # Wait for the deposit to be complete.
    object_druid = nil

    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        result = SdrClient::BackgroundJobResults.show(url: Settings.sdrapi_url, job_id:)
        raise result[:output][:errors] if result[:output][:errors].present?

        object_druid = result[:output][:druid]
        break if object_druid
      end
    end

    raise 'Did not receive druid from SDR deposit' if object_druid.nil?

    object_druid
  end

  # rubocop:disable Metrics/MethodLength
  def deposit_object(filenames: [])
    files_metadata = {}
    grouping_strategy = SdrClient::Deposit::SingleFileGroupingStrategy
    if filenames.any?
      grouping_strategy = SdrClient::Deposit::MatchingFileGroupingStrategy
      files_metadata = {
        filenames.first => { 'preserve' => true, 'publish' => false, 'shelve' => false },
        filenames.last => { 'preserve' => false, 'publish' => true, 'shelve' => true }
      }
      file_set_type_strategy = SdrClient::Deposit::ImageFileSetStrategy
    end

    object_druid = deposit(apo: Settings.default_apo,
                           collection: Settings.default_collection,
                           url: Settings.sdrapi_url,
                           type: Cocina::Models::ObjectType.image,
                           source_id: "virtual-object-test:#{SecureRandom.uuid}",
                           accession: true,
                           view: 'world',
                           label: random_phrase,
                           grouping_strategy:,
                           file_set_type_strategy:,
                           files: filenames,
                           basepath: 'spec/fixtures',
                           files_metadata:)

    visit "#{start_url}/view/#{object_druid}"

    # Wait for indexing and workflows to finish
    reload_page_until_timeout!(text: 'v1 Accessioned')

    object_druid
  end
  # rubocop:enable Metrics/MethodLength
end
