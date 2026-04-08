# frozen_string_literal: true

# Broadcasts widget typing indicator while waiting for the 4AY API (uses ActionCable, same as agent typing).
module FourAy
  class TypingBroadcast
    class << self
      def around_ai_reply(conversation)
        user = typing_actor_for(conversation)
        if user.blank?
          yield
          return
        end

        dispatch(Events::Types::CONVERSATION_TYPING_ON, conversation, user)
        yield
      ensure
        dispatch(Events::Types::CONVERSATION_TYPING_OFF, conversation, user) if user.present?
      end

      private

      def typing_actor_for(conversation)
        inbox = conversation.inbox
        inbox.agent_bot || inbox.members.first || conversation.account.administrators.first
      end

      def dispatch(event_name, conversation, user)
        Rails.configuration.dispatcher.dispatch(
          event_name,
          Time.zone.now,
          conversation: conversation,
          user: user,
          is_private: false
        )
      end
    end
  end
end
