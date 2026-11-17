# frozen_string_literal: true

# Helpers for moving through the steps of managing files in Argo-B3
module ArgoB3ManageFilesHelpers
  # @param label [String] the current step of managing files, e.g., Add and edit files
  def expect_manage_files_step(label)
    expect(page).to have_css('li[aria-current="step"]', text: label)
  end

  # Leaves the add and edit files step, which structures (or appends) the files in the background.
  def structure_files_from_files_step
    click_button 'Next'
    expect_manage_files_step('Structure files')
    # The wait page refreshes itself until structuring is complete.
    expect(page).to have_css('h3', text: /\AResources/)
  end

  # @param version_description [String] only for redeposits, since there is none for a first version
  def deposit_from_manage_files(version_description: nil)
    click_button 'Next'
    expect_manage_files_step('Deposit')
    fill_in 'Version description', with: version_description if version_description
    # The step label is also "Deposit", so match the button exactly.
    click_button 'Deposit', exact: true
  end
end

RSpec.configure { |config| config.include ArgoB3ManageFilesHelpers }
