# frozen_string_literal: true

module BulkActionHelpers
  # Polls for a bulk action identified by description to complete.
  # Yields within the completed row's context for assertions.
  #
  # @param description [String] the bulk action description text to find in the table
  # @param timeout [Integer] seconds to wait (default: Settings.timeouts.bulk_action)
  def wait_for_bulk_action_completion!(description:, timeout: Settings.timeouts.bulk_action)
    Timeout.timeout(timeout) do
      loop do
        page.refresh

        row = find(:xpath, "//tr[td = '#{description}']")
        status_cell = row.find('td:nth-child(4)')

        next unless status_cell.text == 'Completed'

        within(row) { yield if block_given? }
        break
      end
    end
  end
end

RSpec.configure { |config| config.include BulkActionHelpers }
