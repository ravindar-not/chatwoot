# frozen_string_literal: true

class FourAy::ReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return if message.blank?
    return unless message.incoming?
    return if message.private?
    return unless message.inbox.web_widget?
    return unless message.content_type == 'text'
    return if message.content.blank?

    conversation = message.conversation

    reply_text = nil
    FourAy::TypingBroadcast.around_ai_reply(conversation) do
      reply_text = FourAy::Service.get_response(
        message.content,
        conversation_id: message.conversation_id
      )
    end

    return if reply_text.blank?

    conversation.messages.create!(
      content: reply_text,
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: conversation.inbox.agent_bot
    )
  end
end
