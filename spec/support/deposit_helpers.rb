# frozen_string_literal: true

module DepositHelpers
  def deposit(**kwargs)
    job_id = SdrClient::Deposit.run(kwargs)

    # Wait for the deposit to be complete.
    object_druid = nil

    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        result = SdrClient::BackgroundJobResults.show(url: API_URL, job_id: job_id)
        raise result[:output][:errors] if result[:output][:errors].present?

        object_druid = result[:output][:druid]
        break if object_druid
      end
    end

    raise 'Did not receive druid from SDR deposit' if object_druid.nil?

    object_druid
  end
end
