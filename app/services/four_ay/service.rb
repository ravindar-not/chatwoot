# frozen_string_literal: true

module FourAy
  # Orchestrates 4AY agent calls: query + agent_id resolution, HTTP client, response parsing.
  class Service
    DEFAULT_FALLBACK_REPLY = 'Thanks for your message. Our team will get back to you shortly.'.freeze
    API_EXECUTE_PATH = '/dynamic-agent/execute'

    class << self
      # @return [Hash] +:reply+ (String), +:stream_id+ (String, nil) when streaming to widget
      def fetch_reply(query, conversation_id:, agent_id: nil, user_role: nil, conversation: nil)
        empty = { reply: DEFAULT_FALLBACK_REPLY, stream_id: nil }
        content = query.to_s.strip
        return empty if content.blank?

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
        streaming_enabled = streaming.strip.casecmp('true').zero?
        use_streaming_http = streaming_enabled && conversation&.inbox&.web_widget?
        request_streaming = use_streaming_http ? 'true' : 'false'
        if endpoint.blank? || api_key.blank?
          Rails.logger.error 'FourAy::Service: FOUR_AY_API_BASE_URL or FOUR_AY_API_KEY is missing'
          return empty
        end

        if resolved_agent_id.blank?
          Rails.logger.warn 'FourAy::Service: no agent id (set four_ay_agent_id on contact/conversation, pass agent_id:, or FOUR_AY_DEFAULT_AGENT_ID)'
          return empty
        end

        session_id = build_session_id(resolved_agent_id, conversation_id)
        variables = { user_role: resolved_user_role }.to_json

        body = {
          agent_id: resolved_agent_id,
          query: content,
          session_id: session_id,
          streaming: request_streaming,
          variables: variables
        }

        Rails.logger.info(
          "FourAy::Service: agent_id=#{resolved_agent_id} session_id=#{session_id} user_role=#{resolved_user_role}"
        )

        stream_id = (use_streaming_http ? SecureRandom.uuid : nil)
        last_streamed = nil
        last_stream_broadcast_mono = nil
        stream_broadcast_min_interval_s =
          ENV.fetch('FOUR_AY_STREAM_BROADCAST_MS', '80').to_f.clamp(16.0, 500.0) / 1000.0

        response = if use_streaming_http
                     Integrations::FourAy::StreamResponse.post_form(
                       endpoint: endpoint,
                       api_key: api_key,
                       body: body
                     ) do |buffer|
                       next if stream_id.blank? || conversation.blank?

                       text = Integrations::FourAy::ResponseParser.extract_reply_unified(buffer)
                       next if text.blank? || text == last_streamed

                       now_mono = Process.clock_gettime(Process::CLOCK_MONOTONIC)
                       if last_stream_broadcast_mono &&
                          (now_mono - last_stream_broadcast_mono) < stream_broadcast_min_interval_s
                         next
                       end

                       last_stream_broadcast_mono = now_mono
                       last_streamed = text.dup

                       FourAy::ReplyStreamBroadcaster.broadcast_chunk(
                         conversation: conversation,
                         stream_id: stream_id,
                         content: text
                       )
                     end
                   else
                     Integrations::FourAy::ApiClient.post_chat(
                       endpoint: endpoint,
                       api_key: api_key,
                       body: body
                     )
                   end

        unless response.success?
          Rails.logger.error "FourAy::Service HTTP #{response.code}: #{response.body.to_s[0..300]}"
          return empty
        end

        reply = Integrations::FourAy::ResponseParser
                .extract_reply_unified(response.parsed_response)
                .presence || DEFAULT_FALLBACK_REPLY
        { reply: reply, stream_id: stream_id }
      rescue StandardError => e
        Rails.logger.error "FourAy::Service error: #{e.class} - #{e.message}"
        empty
      end

      # @param conversation [Conversation, nil] when set with STREAMING=true, partial replies broadcast to the widget.
      def get_response(query, conversation_id:, agent_id: nil, user_role: nil, conversation: nil)
        fetch_reply(
          query,
          conversation_id: conversation_id,
          agent_id: agent_id,
          user_role: user_role,
          conversation: conversation
        )[:reply]
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
