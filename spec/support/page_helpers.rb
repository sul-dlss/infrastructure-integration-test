# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text: '')
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        break if block_given? ? yield : page.has_text?(text, wait: 1)

        # Check for workflow errors and bail out early. There is no recovering
        # from a workflow error. This selector is found on the Argo item page.
        expect(page).not_to have_css('.alert-danger', wait: 0)

        page.refresh
      end
    end
  end

  # Some workflow steps fail due to race conditions or other temporary annoyances.
  # This method provides a way to retry a workflow step if the workflow fails with a specific error message
  def reload_page_until_timeout_with_wf_step_retry!(expected_text: '',
                                                    workflow: 'accessionWF',
                                                    workflow_retry_text: '',
                                                    retry_wait: 5)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        break if block_given? ? yield : page.has_text?(expected_text, wait: 1)

        if page.has_css?('.alert-danger', wait: 0) && page.has_text?(workflow_retry_text)
          click_link workflow
          select 'Rerun', from: 'status'
          confirm_message = 'You have selected to manually change the status. '
          confirm_message += 'This could result in processing errors. Are you sure you want to proceed?'
          accept_confirm(confirm_message) do
            click_button 'Save'
          end
          sleep retry_wait
        end

        page.refresh
      end
    end
  end
end

RSpec.configure { |config| config.include PageHelpers }
