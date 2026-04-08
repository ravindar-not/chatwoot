# frozen_string_literal: true

module FourAy
  # Resolves 4AY user_role: optional override, then conversation/contact custom attributes (via conversation_id), then "guest".
  class UserRoleResolver
    CUSTOM_KEY = 'user_role'

    class << self
      def resolve(user_role: nil, conversation_id: nil)
        new(user_role: user_role, conversation_id: conversation_id).resolve
      end
    end

    def initialize(user_role: nil, conversation_id: nil)
      @user_role = user_role
      @conversation_id = conversation_id
    end

    def resolve
      explicit_user_role.presence ||
        from_conversation_custom_attributes.presence ||
        from_contact_custom_attributes.presence ||
        'guest'
    end

    private

    attr_reader :user_role, :conversation_id

    def explicit_user_role
      return if user_role.nil?

      user_role.to_s.strip
    end

    def conversation
      return if conversation_id.blank?

      @conversation ||= Conversation.find_by(id: conversation_id)
    end

    def from_conversation_custom_attributes
      return if conversation.blank?

      extract(conversation.custom_attributes)
    end

    def from_contact_custom_attributes
      return if conversation.blank? || conversation.contact.blank?

      extract(conversation.contact.custom_attributes)
    end

    def extract(attrs)
      return if attrs.blank?

      attrs = attrs.stringify_keys
      attrs[CUSTOM_KEY].to_s.presence
    end
  end
end
