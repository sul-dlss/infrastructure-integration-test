# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text: '')
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        break if block_given? ? yield : page.has_text?(text, wait: 1)

        # NOTE: This is here to work around a persistent, not easily
        #       reproducible race condition that is occasionally seen in Argo,
        #       causing integration tests to fail. This work-around mimics the
        #       steps that developers tend to perform manually.
        if page.has_text?('Error: shelve : problem with shelve', wait: 0)
          reset_errored_workflow_step!('accessionWF')
          sleep 3
        else
          # Check for workflow errors and bail out early. There is no recovering
          # from a workflow error. This selector is found on the Argo item page.
          expect(page).not_to have_css('.alert-danger', wait: 0)
        end

        page.refresh
      end
    end
  end

  # resets the first errored out step in the given workflow
  def reset_errored_workflow_step!(workflow_name)
    click_link workflow_name
    select 'Rerun', from: 'status'
    confirm_message = 'You have selected to manually change the status. '
    confirm_message += 'This could result in processing errors. Are you sure you want to proceed?'
    accept_confirm(confirm_message) do
      click_button 'Save'
    end
  end
end
