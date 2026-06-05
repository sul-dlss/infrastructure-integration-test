# frozen_string_literal: true

require 'amatch'
require 'webvtt'

module TranscriptionHelpers
  # Calculates Word Error Rate (WER) by mapping each unique word to a single Unicode character.
  # This "word-to-character mapping" allows the character-based Amatch C extension to perform
  # accurate word-level Levenshtein distance calculations (where 1 word change = 1 edit).
  def calculate_wer(reference_path, hypothesis_path, format: :text)
    ref_words = load_and_normalize(reference_path, format)
    hyp_words = load_and_normalize(hypothesis_path, format)

    return 0.0 if ref_words.empty? && hyp_words.empty?
    return 1.0 if ref_words.empty?

    # Map words to unique characters so that word-level edits equal character-level edits
    vocabulary = (ref_words + hyp_words).uniq
    word_to_char = vocabulary.each_with_index.to_h { |word, i| [word, [i].pack('U')] }

    ref_encoded = ref_words.map { |w| word_to_char[w] }.join
    hyp_encoded = hyp_words.map { |w| word_to_char[w] }.join

    Amatch::Levenshtein.new(ref_encoded).match(hyp_encoded).to_f / ref_words.size
  end

  private

  def load_and_normalize(path, format)
    text = format == :vtt ? extract_vtt_text(path) : File.read(path)
    text.downcase.gsub(/[[:punct:]]/, '').split
  end

  def extract_vtt_text(path)
    vtt = WebVTT.read(path)
    vtt.cues.map(&:plain_text).join(' ')
  end
end

RSpec.configure { |config| config.include TranscriptionHelpers }
