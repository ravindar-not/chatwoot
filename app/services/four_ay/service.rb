# frozen_string_literal: true

module FourAy
  # Orchestrates 4AY agent calls: query + agent_id resolution, HTTP client, response parsing.
  class Service
    DEFAULT_FALLBACK_REPLY = 'Thanks for your message. Our team will get back to you shortly.'.freeze
    API_EXECUTE_PATH = '/dynamic-agent/execute'

    class << self
      # @param conversation_id [Integer] Chatwoot Conversation primary key (used for session_id and resolving agent from custom attrs).
      # @param agent_id [String, nil] optional override; otherwise resolved from DB via conversation_id or FOUR_AY_DEFAULT_AGENT_ID.
      # @param user_role [String, nil] optional override for variables.user_role; otherwise from contact/conversation custom_attributes["user_role"], default "guest".
      def get_response(query, conversation_id:, agent_id: nil, user_role: nil)
        content = query.to_s.strip
        return DEFAULT_FALLBACK_REPLY if content.blank?

        endpoint = execute_endpoint_url
        api_key = ENV.fetch('FOUR_AY_API_KEY', '').to_s
        resolved_agent_id = AgentResolver.resolve(
          agent_id: agent_id,
          conversation_id: conversation_id
        )
        resolved_user_role = UserRoleResolver.resolve(
          user_role: user_role,
          conversation_id: conversation_id
        )

        streaming = ENV.fetch('STREAMING', 'false').to_s
        if endpoint.blank? || api_key.blank?
          Rails.logger.error 'FourAy::Service: FOUR_AY_API_BASE_URL or FOUR_AY_API_KEY is missing'
          return DEFAULT_FALLBACK_REPLY
        end

        if resolved_agent_id.blank?
          Rails.logger.warn 'FourAy::Service: no agent id (set four_ay_agent_id on contact/conversation, pass agent_id:, or FOUR_AY_DEFAULT_AGENT_ID)'
          return DEFAULT_FALLBACK_REPLY
        end

        session_id = build_session_id(resolved_agent_id, conversation_id)
        variables = { user_role: resolved_user_role }.to_json

        body = {
          agent_id: resolved_agent_id,
          query: content,
          session_id: session_id,
          streaming: streaming,
          variables: variables
        }

        Rails.logger.info(
          "FourAy::Service: agent_id=#{resolved_agent_id} session_id=#{session_id} user_role=#{resolved_user_role}"
        )

        response = Integrations::FourAy::ApiClient.post_chat(
          endpoint: endpoint,
          api_key: api_key,
          body: body
        )

        if response.success?
          Integrations::FourAy::ResponseParser.extract_reply(response.parsed_response).presence || DEFAULT_FALLBACK_REPLY
        else
          Rails.logger.error "FourAy::Service HTTP #{response.code}: #{response.body.to_s[0..300]}"
          DEFAULT_FALLBACK_REPLY
        end
      rescue StandardError => e
        Rails.logger.error "FourAy::Service error: #{e.class} - #{e.message}"
        DEFAULT_FALLBACK_REPLY
      end

      def execute_endpoint_url
        base = ENV.fetch('FOUR_AY_API_BASE_URL', '').to_s.strip.chomp('/')
        return '' if base.blank?

        "#{base}#{API_EXECUTE_PATH}"
      end

      private

      def build_session_id(agent_id, conversation_id)
        "#{agent_id}-chatwoot-#{conversation_id}"
      end
    end
  end
end
