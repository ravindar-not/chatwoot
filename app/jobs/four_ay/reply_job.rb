# frozen_string_literal: true

class FourAy::ReplyJob < ApplicationJob
  queue_as :default

  def perform(message_id)
    message = Message.find_by(id: message_id)
    return if message.blank?
    return unless message.incoming?
    return if message.private?
    return unless message.content_type == 'text'
    return if message.content.blank?
    return unless FourAy::ChannelGuard.allowed?(message)

    conversation = message.conversation
    resolution = FourAy::InboxAgentResolution.call(inbox: conversation.inbox, conversation: conversation)

    reply_text = nil
    FourAy::TypingBroadcast.around_ai_reply(conversation) do
      reply_text = if resolution[:blocked]
                     resolution[:message]
                   else
                     FourAy::Service.get_response(
                       message.content,
                       conversation_id: message.conversation_id,
                       agent_id: resolution[:agent_id]
                     )
                   end
    end

    return if reply_text.blank?

    sender = bot_sender_for(conversation.inbox)
    return if sender.blank?

    conversation.messages.create!(
      content: reply_text,
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: sender
    )
  end

  def bot_sender_for(inbox)
    inbox.agent_bot || AgentBot.accessible_to(inbox.account).first
  end
end
