# frozen_string_literal: true

# Parses 4AY API JSON/string responses into a single reply string.
class Integrations::FourAy::ResponseParser
  REPLY_KEYS = %w[reply response content answer output].freeze

  class << self
    def extract_reply(raw)
      hash = normalize_to_hash(raw)
      return raw.to_s if hash.nil?

      extract_text_from_hash(hash)
    end

    private

    def extract_text_from_hash(hash)
      REPLY_KEYS.each do |key|
        val = hash[key]
        next if val.nil?
        return val.to_s unless val.is_a?(Hash)

        nested = extract_text_from_hash(val)
        return nested if nested.present?
      end

      REPLY_KEYS.each do |key|
        val = hash.dig('data', key)
        next if val.nil?
        return val.to_s unless val.is_a?(Hash)
      end

      nil
    end

    def normalize_to_hash(raw)
      return nil if raw.nil?
      return raw.stringify_keys if raw.is_a?(Hash)

      parsed = JSON.parse(raw.to_s)
      parsed.is_a?(Hash) ? parsed : nil
    rescue JSON::ParserError
      nil
    end
  end
end
