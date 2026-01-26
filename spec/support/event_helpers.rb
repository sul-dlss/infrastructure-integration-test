# frozen_string_literal: true

require 'dor/services/client'

module EventHelpers
  env_name = $sdr_env == 'stage' ? '_stage' : ''
  TARGET_ENDPOINT_NAMES = ["aws_s3_west_2#{env_name}", 'gcp_s3_south_1', "aws_s3_east_1#{env_name}"].freeze

  # @param [String] druid the druid to check for replication events, will be normalized to the prefixed version
  # @param [String,int] version the version to check for successful replication (naively assumes <= 9)
  def visit_argo_and_confirm_event_display!(druid:, version:)
    prefixed_druid = druid.start_with?('druid:') ? druid : "druid:#{druid}"
    visit "#{Settings.argo_url}/view/#{prefixed_druid}"
    druid_tree_str = DruidTools::Druid.new(prefixed_druid).tree.join('/')

    latest_s3_key = "#{druid_tree_str}.v000#{version}.zip"
    reload_page_until_timeout! do
      click_link_or_button 'Events' # expand the Events section

      # this is a hack that forces the event section to scroll into view; the section
      # is lazily loaded, and won't actually be requested otherwise, even if the button
      # is clicked to expand the event section.
      page.execute_script 'window.scrollBy(0,100);'

      expect(page).to have_css('turbo-frame#events[complete]', wait: 5) # wait for events to load
      all('turbo-frame#events a', text: 'Expand all').each(&:click) # expand all event details
      page.has_text?(latest_s3_key)
    end
  end

  # The event log should eventually contain an event for replication of each version that
  # the test created, to every endpoint we archive to. Confirm the expected events exist.
  # @param [String] druid the druid to check for replication events, will be normalized to the prefixed version
  # @param [String,int] from_version the lowest version to check for successful replication, inclusive
  # @param [String,int] to_version the highest version to check for successful replication, inclusive (naively assumes <= 9)
  def confirm_archive_zip_replication_events!(druid:, from_version:, to_version:) # rubocop:disable Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity
    prefixed_druid = druid.start_with?('druid:') ? druid : "druid:#{druid}"
    druid_tree_str = DruidTools::Druid.new(prefixed_druid).tree.join('/')

    # The below confirms that preservation replication is working: we only replicate a
    # Moab version once it's been written successfully to on prem storage roots, and
    # we only log an event to dor-services-app after a version has successfully replicated
    # to a cloud endpoint.  So, confirming that all versions of a test object have
    # replication events logged for all expected cloud endpoints is a good basic test of the
    # entire preservation flow.
    poll_for_matching_events!(prefixed_druid) do |events|
      (from_version..to_version).all? do |cur_version|
        cur_s3_key = "#{druid_tree_str}.v000#{cur_version}.zip"

        puts "searching events for #{cur_s3_key} replication to all of #{TARGET_ENDPOINT_NAMES}"
        events_were_found = TARGET_ENDPOINT_NAMES.all? do |endpoint_name|
          events.any? do |event|
            event[:event_type] == 'druid_version_replicated' &&
              event[:data]['parts_info'] &&
              event[:data]['parts_info'].size == 1 && # we only expect one part for our small test objects
              event[:data]['parts_info'].first['s3_key'] == cur_s3_key &&
              event[:data]['endpoint_name'] == endpoint_name
          end
        end

        puts("#{cur_s3_key} replication events found for all endpoints") if events_were_found
        events_were_found
      end
    end
  end

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

RSpec.configure { |config| config.include EventHelpers }
