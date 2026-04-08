# frozen_string_literal: true

# Low-level HTTP client for the 4AY (Quadroid) agent API. Single responsibility: perform the request.
# Uses form-encoded body (same as HTTParty default for Hash body) — the upstream API expects this, not JSON.
class Integrations::FourAy::ApiClient
  include HTTParty

  DEFAULT_TIMEOUT = 180

  class << self
    def post_chat(endpoint:, api_key:, body:, timeout: DEFAULT_TIMEOUT)
      raise ArgumentError, 'endpoint is required' if endpoint.blank?
      raise ArgumentError, 'api_key is required' if api_key.blank?

      # Stringify values for x-www-form-urlencoded (matches legacy FourAy::Service behavior).
      form_body = body.transform_values { |v| v.nil? ? '' : v.to_s }

      HTTParty.post(
        endpoint,
        headers: { 'x-api-key' => api_key },
        body: form_body,
        timeout: timeout
      )
    end
  end
end
