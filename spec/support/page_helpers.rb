# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text: '', num_seconds: Settings.timeouts.workflow)
    Timeout.timeout(num_seconds) do
      loop do
        found = block_given? ? yield : page.has_text?(text, wait: 1)
        if found
          page.refresh
          break
        end

        # Check for workflow errors and bail out early.
        expect(page).to have_no_css('.alert-danger', wait: 0)

        page.refresh
      end
    end
  end

  def reload_page_until_timeout_with_wf_step_retry!(expected_text: '', # rubocop:disable Metrics/MethodLength
                                                    workflow: 'accessionWF',
                                                    workflow_retry_text: '',
                                                    retry_wait: 5)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        if block_given?
          yield_val = yield(page)
          break if yield_val == true

          workflow = yield_val if yield_val.is_a?(String)
        else
          break if page.has_text?(expected_text, wait: 1)
        end

        if page.has_css?('.alert-danger', wait: 0) && page.has_text?(workflow_retry_text)
          within('#document-history-section') do
            click_link_or_button workflow
          end
          select 'Rerun', from: 'status'
          confirm_message = 'You have selected to manually change the status. '
          confirm_message += 'This could result in processing errors. Are you sure you want to proceed?'
          accept_confirm(confirm_message) do
            click_link_or_button 'Save'
          end
          sleep retry_wait
        end

        page.refresh
      end
    end
  end
end

RSpec.configure { |config| config.include PageHelpers }
