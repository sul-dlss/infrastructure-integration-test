# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text:, as_link: false)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        page.evaluate_script('location.reload();')

        # NOTE: This could have been a ternary but I was concerned about its
        #       readability.
        if as_link
          break if page.has_link?(text, wait: 1)
        else
          break if page.has_text?(text, wait: 1)
        end
      end
    end
  end
end
