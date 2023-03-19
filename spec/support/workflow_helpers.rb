# frozen_string_literal: true

module WorkflowHelpers
  # resets the first errored out step in the given workflow
  def reset_errored_workflow_step(workflow_name)
    click_link workflow_name
    select 'Rerun', from: 'status'
    confirm_message = 'You have selected to manually change the status. '
    confirm_message += 'This could result in processing errors. Are you sure you want to proceed?'
    accept_confirm(confirm_message) do
      click_button 'Save'
    end
  end
end
