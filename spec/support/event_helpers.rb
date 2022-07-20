# frozen_string_literal: true

module EventHelpers
  # pass in a block that returns true if the event list has the desired event(s)
  def poll_for_matching_events!(prefixed_druid)
    Dor::Services::Client.configure(url: Settings.dor_services.url, token: Settings.dor_services.token)

    # In case we pass in a non-prefixed druid
    prefixed_druid = "druid:#{prefixed_druid}" unless prefixed_druid.start_with?('druid:')

    object_client = Dor::Services::Client.object(prefixed_druid)

    Timeout.timeout(Settings.timeouts.events.poll_for) do
      loop do
        events = object_client.events.list
        break if yield(events)

        sleep Settings.timeouts.events.poll_interval
      end
    end
  end
end
