# frozen_string_literal: true

# Helpers for Argo-B3's searchable (Tom Select) selects, e.g., APO
module SearchableSelectHelpers
  # Chooses an option of a searchable (Tom Select) select, e.g., APO, which hides the underlying select.
  def select_searchable_option(option_label, from:)
    wrapper = find_searchable_select(from)
    # After choosing an option the field keeps focus, and clicking it then would close it rather than open it.
    wrapper.find('.ts-control').click unless wrapper.matches_css?('.focus', wait: 0)
    # Typed into the focused input, since Tom Select moves it offscreen while an option is chosen.
    wrapper.find('.ts-control input:focus', visible: :all)
    send_keys(option_label)
    wrapper.find('.ts-dropdown .option', exact_text: option_label).click
    # Tom Select leaves the dropdown open when the option clicked was already chosen.
    send_keys(:escape) if wrapper.matches_css?('.dropdown-active', wait: 0)
  end

  # Chooses the option with the given value (e.g., an APO druid), since Tom Select searches only option labels.
  def select_searchable_option_by_value(value, from:)
    select_id = find_searchable_input(from)[:id].delete_suffix('-ts-control')
    option = find_by_id(select_id, visible: :all).find("option[value='#{value}']", visible: :all)
    select_searchable_option(option.text(:all), from:)
  end

  # Tom Select points the label at the input it renders for typing, which is hidden until the control is opened.
  def find_searchable_input(label)
    find_by_id(find('label', text: /\A#{Regexp.escape(label)}\b/)[:for], visible: :all)
  end

  def find_searchable_select(label)
    find_searchable_input(label).ancestor('.ts-wrapper')
  end
end

RSpec.configure { |config| config.include SearchableSelectHelpers }
