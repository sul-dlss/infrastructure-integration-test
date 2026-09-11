# frozen_string_literal: true

module PreservationHelpers
  def retrieve_and_fixity_check_replicated_druid!(druid:, expected_version:)
    bare_druid = bare_druid(druid)

    fixity_check_cmd = 'cd preservation_catalog/current && RAILS_ENV=production bin/fixity_check_replicated_moabs ' \
                       "--druid_list #{bare_druid} --endpoints_to_audit gcp_s3_south_1"
    remote_destination = "#{Settings.preservation_catalog.username}@#{Settings.preservation_catalog.host}"
    remote_fixity_check_cmd = "ssh #{remote_destination} '#{fixity_check_cmd}'"
    stdout_str, stderr_str, status =
      begin
        Open3.capture3(remote_fixity_check_cmd)
      rescue StandardError => e
        puts "Error executing system command: '#{remote_fixity_check_cmd}' raised #{e}"
      end

    cmd_result = {
      cmd: remote_fixity_check_cmd, stdout_str:, stderr_str:, exitstatus: status.exitstatus, success: status.success?
    }
    puts cmd_result
    expect(cmd_result[:exitstatus]).to eq 0
    expect(cmd_result[:success]).to be true
    expect(stdout_str).to match(/fixity check passed - validate_checksums - #{bare_druid}.*actual version: #{expected_version}/)
  end

  def confirm_moab_fully_replicated_and_retrievable!(druid:, latest_version:)
    # A quick check to make sure that the events are displaying in Argo, by looking for
    # the latest.  Then more thorough checks to see that all the expected events were
    # recorded, and that the replicated Moab can be retrieved and reconstituted.
    visit_argo_and_confirm_replication_event_display!(druid:, version: latest_version)
    confirm_archive_zip_replication_events!(druid:, to_version: latest_version)
    retrieve_and_fixity_check_replicated_druid!(druid:, expected_version: latest_version)
  end
end

RSpec.configure { |config| config.include PreservationHelpers }
