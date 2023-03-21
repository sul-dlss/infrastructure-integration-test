# frozen_string_literal: true

# These helpers are particularly helpful given the design of Argo circa 2022
module TableHelpers
  def find_table_cell_following(header_text:)
    find(:xpath, "//tr/th[text()='#{header_text}']/following-sibling::td")
  end
end

RSpec.configure { |config| config.include TableHelpers }
