# frozen_string_literal: true

# This module helps with common actions in the self deposit app (H2)
module H2Helpers
  # all-in-one convenience method for submitting the deposit form and
  # handling the modal if one is shown
  def click_deposit_and_handle_terms_modal
    sleep 0.5 # wait for everything to settle
    click_link_or_button 'Deposit'
    click_through_terms_of_deposit_modal
  end

  # if a terms of deposit modal is showing, click through it, otherwise do nothing
  def click_through_terms_of_deposit_modal
    return unless terms_of_deposit_modal_showing?

    click_close_then_click_deposit
  end

  def terms_of_deposit_modal_showing?
    # a bit fragile/un-user-like to use a CSS selector, but the alternative would be
    # to use very specific substrings from the terms, which also feels fragile.
    return false unless page.has_css?('div.modal', visible: true, wait: modal_selector_wait)

    within('div.modal') do
      return page.has_text?(:visible, 'Terms of Deposit', wait: modal_selector_wait) &&
             page.has_button?('Close', wait: modal_selector_wait)
    end
  end

  def click_close_then_click_deposit
    find_button('Close').click # for some reason this works where click_link_or_button('Close') does not :shrug:
    sleep 2 # modal can take a moment or two to go away
    click_button 'Deposit'
    sleep 2 # form can take a moment or two to submit
  end

  def modal_selector_wait
    Settings.timeouts.h2_terms_modal_wait
  end
end

RSpec.configure { |config| config.include H2Helpers }
