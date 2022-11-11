# frozen_string_literal: true

module PageHelpers
  # rubocop:disable Metrics/CyclomaticComplexity
  # rubocop:disable Metrics/MethodLength
  # rubocop:disable Metrics/PerceivedComplexity
  # rubocop:disable Metrics/ParameterLists
  def reload_page_until_timeout!(text:, as_link: false, table: nil, with_events_expanded: false, selector: nil)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        if with_events_expanded
          click_button 'Events' # expand the Events section

          # this is a hack that forces the event section to scroll into view; the section
          # is lazily loaded, and won't actually be requested otherwise, even if the button
          # is clicked to expand the event section.
          page.execute_script 'window.scrollBy(0,100);'
        end

        wait_time = with_events_expanded ? 3 : 1 # events are loaded lazily, give the network a few moments
        if as_link
          break if page.has_link?(text, wait: wait_time)
        elsif table
          break if page.find(:table_row, table).text.match?(text)
        elsif selector
          break if page.has_selector?(selector, text:, wait: wait_time)
        else
          break if page.has_text?(text, wait: wait_time)
        end

        # Check for workflow errors and bail out early. There is no recovering
        # from a workflow error. This selector is found on the Argo item page.
        expect(page).not_to have_css('.alert-danger', wait: 0)

        page.refresh
      end
    end
  end
  # rubocop:enable Metrics/CyclomaticComplexity
  # rubocop:enable Metrics/MethodLength
  # rubocop:enable Metrics/PerceivedComplexity
  # rubocop:enable Metrics/ParameterLists
end
