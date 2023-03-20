# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text: '', check_wf_error: true)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        break if block_given? ? yield : page.has_text?(text, wait: 1)

        # Check for workflow errors and bail out early. There is no recovering
        # from a workflow error. This selector is found on the Argo item page.
        expect(page).not_to have_css('.alert-danger', wait: 0) if check_wf_error

        page.refresh
      end
    end
  end
end
