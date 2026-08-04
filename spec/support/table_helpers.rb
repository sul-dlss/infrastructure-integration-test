# frozen_string_literal: true

# These helpers are particularly helpful given the design of Argo circa 2022
module TableHelpers
  def find_table_cell_following(header_text:, xpath_suffix: '')
    find(:xpath, "//tr/th[text()=#{xpath_string(header_text)}]/following-sibling::td#{xpath_suffix}")
  end

  private

  # Properly escape a string for use in XPath expressions.
  # Handles strings containing single quotes, double quotes, or both.
  def xpath_string(str)
    if !str.include?("'")
      "'#{str}'"
    elsif !str.include?('"')
      "\"#{str}\""
    else
      "concat('#{str.split("'").join("',\"'\",'")}')"
    end
  end
end

RSpec.configure { |config| config.include TableHelpers }
