# frozen_string_literal: true

# Enqueues a 4AY reply when visitors send text messages via the web widget.
class FourAyListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return unless four_ay_enabled?
    return unless message.incoming?
    return if message.private?
    return unless message.inbox.web_widget?
    return unless message.content_type == 'text'
    return if message.content.blank?
    return if agent_bot_webhook_configured?(message.inbox)

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
