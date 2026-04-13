# frozen_string_literal: true

module FourAy
  # Website widget: always allowed for FourAY (no email verification mail, no external agent lookup).
  # Other channels: require a +Contact+ sender. If the inbox does not require database verification,
  # allow the AI without email verification. If it does, inbound email verification must be enabled
  # globally and the contact must be email-verified.
  module ChannelGuard
    class << self
      def allowed?(message)
        return true if message.inbox.web_widget?
        return false unless message.sender.is_a?(Contact)

        inbox = message.inbox
        return true unless inbox.four_ay_db_verification_required?

        InboundEmailVerification::Handler.feature_enabled? &&
          InboundEmailVerification::Handler.email_verified?(message.sender)
      end
    end
  end
end
