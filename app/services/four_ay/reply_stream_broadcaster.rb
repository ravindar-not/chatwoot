# frozen_string_literal: true

module FourAy
  # Pushes partial FourAY reply text to the website widget over ActionCable (contact pubsub tokens).
  class ReplyStreamBroadcaster
    class << self
      def broadcast_chunk(conversation:, stream_id:, content:)
        return if conversation.blank? || stream_id.blank? || content.blank?

        payload = {
          conversation_id: conversation.display_id,
          stream_id: stream_id,
          content: content
        }
        contact_pubsub_tokens(conversation).each do |token|
          ActionCable.server.broadcast(
            token,
            { event: Events::Types::FOUR_AY_REPLY_STREAM, data: payload }
          )
        end
      end

      def contact_pubsub_tokens(conversation)
        ci = conversation.contact_inbox
        return [] if ci.blank?

        contact = ci.contact
        if ci.hmac_verified?
          contact.contact_inboxes.where(hmac_verified: true).filter_map(&:pubsub_token)
        else
          [ci.pubsub_token]
        end
      end
    end
  end
end
