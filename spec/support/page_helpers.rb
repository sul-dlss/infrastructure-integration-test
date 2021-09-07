# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text:, as_link: false, with_reindex: false, with_events_expanded: false)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        if with_events_expanded
          find('#document-events-head').click # expand the Events section
        end

        if as_link
          break if page.has_link?(text, wait: 1)
        else
          break if page.has_text?(text, wait: 1)
        end

        # Check for workflow errors and bail out early. There is no recovering
        # from a workflow error. This selector is found on the Argo item page.
        expect(page).not_to have_css('.blacklight-wf_error_ssim', wait: 0)

        if with_reindex
          click_link 'Reindex'
          # ensure we see this message before we do the next thing
          expect(page).to have_text('Successfully updated index for')
        end
        page.driver.browser.navigate.refresh
      end
    end
  end
end
