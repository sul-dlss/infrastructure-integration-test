# frozen_string_literal: true

RSpec::Matchers.define :have_a_complete_step do |selector|
  match do |page|
    page.find(selector)['style'].match?(/background-image/)
  end
end
