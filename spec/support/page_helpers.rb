# frozen_string_literal: true

module PageHelpers
  def reload_page_until_timeout!(text: '', num_seconds: Settings.timeouts.workflow)
    Timeout.timeout(num_seconds) do
      loop do
        break if block_given? ? yield : page.has_text?(text, wait: 1)

        # Check for workflow errors and bail out early. There is no recovering
        # from a workflow error. This selector is found on the Argo item page.
        expect(page).to have_no_css('.alert-danger', wait: 0)

        page.refresh
      end
    end
  end

  # Some workflow steps fail due to race conditions or other temporary annoyances.
  #
  # This method provides a way to retry the last errored step in the specified workflow when there's an alert matching
  # workflow_retry_text.
  # It will stop retrying when the passed in block returns true, or if no block is given, when
  # expected_text is found in the page.
  # Bonus feature/complication: if the block returns a String instead of true or false, that string will be used to
  # choose which workflow is clicked into to reset the last step.  o_O
  #
  # @param expected_text [String,Regexp] the text that will end the refresh loop, if present and no block is provided.
  # @param workflow [String] the workflow in which a step may need to be retried
  # @param workflow_retry_text [String,Regexp] alert text that'll trigger retry of the last failed step of the specified workflow
  #
  # @yieldparam page [Capybara::Node::Document] the currrent page, from which we're retrying the workflow
  # @yieldreturn [boolean,String] done retrying the workflow if true, otherwise continue. if a String, override workflow param
  def reload_page_until_timeout_with_wf_step_retry!(expected_text: '', # rubocop:disable Metrics/MethodLength
                                                    workflow: 'accessionWF',
                                                    workflow_retry_text: '',
                                                    retry_wait: 5)
    Timeout.timeout(Settings.timeouts.workflow) do
      loop do
        # break if block_given? ? yield(page) : page.has_text?(expected_text, wait: 1)
        if block_given?
          yield_val = yield(page)
          break if yield_val == true

          workflow = yield_val if yield_val.is_a?(String)
        else
          break if page.has_text?(expected_text, wait: 1)
        end

        if page.has_css?('.alert-danger', wait: 0) && page.has_text?(workflow_retry_text)
          click_link_or_button workflow
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
