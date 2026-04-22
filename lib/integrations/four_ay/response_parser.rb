# frozen_string_literal: true

# Parses 4AY API JSON/string responses into a single reply string.
# When +streaming: true+, upstream may return Server-Sent Events (+data:+ lines); use +extract_reply_unified+.
#
# FourAY may send *fragmented* SSE: many consecutive +data:+ lines each carrying a tiny piece of one JSON object
# (not RFC-style one event = join(data lines)). We concatenate those fragments and scan for the +answer+ string value.
class Integrations::FourAy::ResponseParser
  REPLY_KEYS = %w[reply response content answer output].freeze

  class << self
    def extract_reply(raw)
      hash = normalize_to_hash(raw)
      return raw.to_s if hash.nil?

      extract_text_from_hash(hash)
    end

    # Handles normal JSON, RFC-style SSE, and FourAY fragmented +data:+ token streams.
    def extract_reply_unified(raw)
      return extract_reply(raw) unless raw.is_a?(String) && sse_like?(raw)

      fragmented = extract_answer_json_string_value(concatenate_fouray_data_fragments(raw))
      standard = extract_reply_from_sse(raw)
      candidates = [fragmented, standard].compact
      best = candidates.max_by { |t| t.to_s.bytesize }
      return best if best.present?

      # Never return the raw SSE string (would broadcast junk before +answer+ exists).
      nil
    end

    # Parses RFC-style SSE: events separated by blank lines, +data:+ lines joined with newlines per spec.
    def extract_reply_from_sse(raw)
      last = nil
      split_sse_events(raw).each do |event_text|
        payload = join_data_lines(event_text)
        next if payload.blank?

        parsed = JSON.parse(payload)
        text = extract_reply(parsed)
        last = text if text.present?
      rescue JSON::ParserError
        next
      end
      last
    end

    private

    def sse_like?(s)
      s.include?("\ndata:") || s.include?("\r\ndata:") || s.start_with?('data:')
    end

    def split_sse_events(raw)
      raw.to_s.gsub("\r\n", "\n").split(/\n\n+/)
    end

    def join_data_lines(event_text)
      parts = []
      event_text.each_line do |line|
        line = line.chomp
        next if line.empty?
        next if line.start_with?(':')

        next unless line.start_with?('data:')

        rest = line.delete_prefix('data:')
        rest = rest.delete_prefix(' ') if rest.start_with?(' ')
        parts << rest
      end
      parts.join("\n")
    end

    # Join every +data:+ payload in order with no separator (FourAY token-chunk stream).
    def concatenate_fouray_data_fragments(raw)
      parts = []
      raw.to_s.each_line do |line|
        line = line.chomp
        next if line.strip.empty?
        next if line.lstrip.start_with?(':')

        next unless line.lstrip.start_with?('data:')

        # SSE allows one optional space after +data:+; further spaces belong to the payload (word boundaries).
        rest = line.sub(/\A\s*data:\s?/, '')
        parts << rest
      end
      parts.join('')
    end

    # Pulls the JSON string value for the last +answer+ key, even if the closing quote has not arrived yet.
    def extract_answer_json_string_value(assembled)
      return nil if assembled.blank?

      key_idx = assembled.rindex('"answer"')
      return nil unless key_idx

      pos = key_idx + '"answer"'.length
      pos += 1 while pos < assembled.length && assembled[pos].match?(/[ \t\r\n]/)
      return nil unless assembled[pos] == ':'

      pos += 1
      pos += 1 while pos < assembled.length && assembled[pos].match?(/[ \t\r\n]/)
      return nil unless assembled[pos] == '"'

      pos += 1
      buf = +''
      escape = false
      while pos < assembled.length
        c = assembled[pos]
        if escape
          case c
          when 'n' then buf << "\n"
          when 't' then buf << "\t"
          when 'r' then buf << "\r"
          when '"', '\\', '/' then buf << c
          else buf << '\\' << c
          end
          escape = false
        elsif c == '\\'
          escape = true
        elsif c == '"'
          break
        else
          buf << c
        end
        pos += 1
      end
      buf.presence
    end

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
