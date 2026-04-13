# frozen_string_literal: true

# Enqueues a 4AY reply for web widget, or non-widget channels when allowed by FourAy::ChannelGuard
# (no email gate unless the inbox requires database verification).
class FourAyListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless four_ay_enabled?
    return unless message.incoming?
    return if message.private?
    return unless message.content_type == 'text'
    return if message.content.blank?
    return if agent_bot_webhook_configured?(message.inbox)
    return unless FourAy::ChannelGuard.allowed?(message)

    FourAy::ReplyJob.perform_later(message.id)
  end

  private

  def four_ay_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('ENABLE_FOUR_AY', 'false'))
  end

  # Avoid duplicate replies when an external agent-bot webhook is already handling the inbox.
  def agent_bot_webhook_configured?(inbox)
    inbox.agent_bot_inbox&.active? && inbox.agent_bot&.outgoing_url.present?
  end
end
