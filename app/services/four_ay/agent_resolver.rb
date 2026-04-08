# frozen_string_literal: true

module FourAy
  # Resolves 4AY agent_id: explicit override, then conversation/contact custom attributes (via conversation_id), then default.
  class AgentResolver
    CUSTOM_AGENT_KEYS = %w[four_ay_agent_id agent_id].freeze

    class << self
      def resolve(agent_id: nil, conversation_id: nil)
        new(agent_id: agent_id, conversation_id: conversation_id).resolve
      end
    end

    def initialize(agent_id: nil, conversation_id: nil)
      @agent_id = agent_id
      @conversation_id = conversation_id
    end

    def resolve
      explicit_agent_id.presence ||
        from_conversation_custom_attributes.presence ||
        from_contact_custom_attributes.presence ||
        default_agent_id.presence
    end

    private

    attr_reader :agent_id, :conversation_id

    def explicit_agent_id
      agent_id.to_s.presence
    end

    def conversation
      return if conversation_id.blank?

      @conversation ||= Conversation.find_by(id: conversation_id)
    end

    def from_conversation_custom_attributes
      return if conversation.blank?

      extract_agent_id(conversation.custom_attributes)
    end

    def from_contact_custom_attributes
      return if conversation.blank? || conversation.contact.blank?

      extract_agent_id(conversation.contact.custom_attributes)
    end

    def extract_agent_id(attrs)
      return if attrs.blank?

      attrs = attrs.stringify_keys
      CUSTOM_AGENT_KEYS.map { |key| attrs[key].presence }.compact.first
    end

    def default_agent_id
      GlobalConfigService.load('FOUR_AY_DEFAULT_AGENT_ID', nil).presence ||
        ENV['FOUR_AY_DEFAULT_AGENT_ID'].presence
    end
  end
end
