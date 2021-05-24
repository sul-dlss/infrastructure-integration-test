# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text:, as_link: false, with_reindex: false)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        if as_link
          break if page.has_link?(text, wait: 1)
        else
          break if page.has_text?(text, wait: 1)
        end

        if with_reindex
          click_link 'Reindex'
          # ensure we see this message before we do the next thing
          expect(page).to have_text('Successfully updated index for')
        else
          page.driver.browser.navigate.refresh
        end
      end
    end
  end
end
