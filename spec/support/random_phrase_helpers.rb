# frozen_string_literal: true

module RandomPhraseHelpers
  def random_phrase
    "#{Faker::Food.spice} #{Faker::Food.ingredient}"
  end

  def random_noun
    Faker::Creature::Bird.common_name.to_s
  end

  def random_alpha
    Faker::Alphanumeric.alpha(number: 6)
  end

  def random_nouns_array
    nouns = []
    3.times { nouns << Faker::Creature::Bird.common_name.to_s }
    nouns
  end

  def random_project_name
    "#{random_nouns_array.join('_')}_#{random_alpha}"
  end
end

RSpec.configure { |config| config.include RandomPhraseHelpers }
