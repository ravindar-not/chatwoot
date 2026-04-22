# frozen_string_literal: true

require 'net/http'

module Integrations
  module FourAy
    # Performs a POST with form body and accumulates the response body via +read_body+ (chunked read).
    # Used when FourAY returns SSE/text-stream so HTTParty does not mishandle the body.
    module StreamResponse
      # Minimal HTTP result compatible with HTTParty-ish callers (+success?, +parsed_response+).
      HttpResult = Struct.new(:code, :body, :success, keyword_init: true) do
        def success?
          success
        end

        def parsed_response
          body
        end
      end

      def self.post_form(endpoint:, api_key:, body:, timeout: ApiClient::DEFAULT_TIMEOUT)
        raise ArgumentError, 'endpoint is required' if endpoint.blank?
        raise ArgumentError, 'api_key is required' if api_key.blank?

        uri = URI.parse(endpoint.to_s)
        form = body.transform_values { |v| v.nil? ? '' : v.to_s }
        buffer = +''
        status_code = nil
        ok = false

        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = (uri.scheme == 'https')
        http.read_timeout = timeout
        http.open_timeout = [timeout, 30].min

        req = Net::HTTP::Post.new(uri.request_uri)
        req['x-api-key'] = api_key
        req.set_form_data(form)

        http.start do
          http.request(req) do |res|
            status_code = res.code.to_s
            ok = res.is_a?(Net::HTTPSuccess)
            res.read_body do |chunk|
              buffer << chunk.to_s
              yield buffer if block_given?
            end
          end
        end

        HttpResult.new(code: status_code, body: buffer, success: ok)
      end
    end
  end
end
