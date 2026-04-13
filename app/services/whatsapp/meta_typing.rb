# frozen_string_literal: true

module Whatsapp
  # Meta WhatsApp Cloud API: mark the customer's message read and show the typing bubble until you send a reply.
  # Triggered from +Whatsapp::IncomingMessageBaseService+ as soon as an inbound message is persisted (earliest UX).
  # https://developers.facebook.com/docs/whatsapp/cloud-api/typing-indicators/
  module MetaTyping
    class << self
      # +incoming_message+ must be the customer's inbound +Message+ (+source_id+ = WhatsApp message id).
      def maybe_send_for_incoming_message(incoming_message)
        return unless usable_incoming?(incoming_message)

        send_cloud_typing(incoming_message.inbox.channel, incoming_message.source_id)
      end

      private

      def usable_incoming?(message)
        return false unless message&.incoming?
        return false unless message.inbox&.whatsapp?

        channel = message.inbox.channel
        channel.is_a?(Channel::Whatsapp) && channel.provider == 'whatsapp_cloud' && message.source_id.present?
      end

      def send_cloud_typing(channel, whatsapp_message_id)
        Whatsapp::Providers::WhatsappCloudService.new(whatsapp_channel: channel).send_typing_indicator(whatsapp_message_id)
      rescue StandardError => e
        Rails.logger.warn "Whatsapp::MetaTyping: #{e.class} #{e.message}"
      end
    end
  end
end
