# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text:, as_link: false, with_reindex: false, with_events_expanded: false)
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
        else
          break if page.has_text?(text, wait: wait_time)
        end

        # Check for workflow errors and bail out early. There is no recovering
        # from a workflow error. This selector is found on the Argo item page.
        expect(page).not_to have_css('.alert-danger', wait: 0)

        if with_reindex
          click_link 'Reindex'
          # ensure we see this message before we do the next thing
          expect(page).to have_text('Successfully updated index for')
        end
        page.refresh
      end
    end
  end
end
