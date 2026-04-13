# frozen_string_literal: true

module FourAy
  # POSTs JSON (+email+, optional +phone_number+ in E.164) to a customer-configured URL and parses
  # { found, four_ay_agent_id }.
  class AgentIdLookup
    TIMEOUT = 15

    class << self
      def fetch(url:, email:, phone_number: nil)
        unless valid_http_url?(url)
          Rails.logger.error("FourAy::AgentIdLookup: invalid URL #{url}")
          return { error: 'invalid_url' }
        end

        token = ENV.fetch('AGENT_ID_ACCESS_TOKEN', '').to_s.strip

        if token.blank?
          Rails.logger.error('FourAy::AgentIdLookup: AGENT_ID_ACCESS_TOKEN is not set')
          return { error: 'agent_id_access_token_missing' }
        end

        headers = {
          'Content-Type' => 'application/json',
          'Accept' => 'application/json',
          'Authorization' => "Bearer #{token}"
        }

        payload = { email: email }
        payload[:phone] = phone_number if phone_number.present?

        response = HTTParty.post(
          url,
          headers: headers,
          body: payload.to_json,
          timeout: TIMEOUT
        )

        return { error: "http_#{response.code}" } unless response.success?

        parsed = response.parsed_response
        parsed = JSON.parse(parsed) if parsed.is_a?(String)
        h = parsed.is_a?(Hash) ? parsed.stringify_keys : {}

        found = ActiveModel::Type::Boolean.new.cast(h['found'])
        agent = h['four_ay_agent_id'].to_s.presence

        { found: found, four_ay_agent_id: agent }
      rescue StandardError => e
        Rails.logger.error("FourAy::AgentIdLookup: #{e.class} #{e.message}")
        { error: e.message }
      end

      def valid_http_url?(url)
        uri = URI.parse(url.to_s)
        uri.is_a?(URI::HTTP) && uri.host.present? && %w[http https].include?(uri.scheme)
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
