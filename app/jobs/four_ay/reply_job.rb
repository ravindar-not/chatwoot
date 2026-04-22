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
    inbox = conversation.inbox
    resolution = FourAy::InboxAgentResolution.call(inbox: inbox, conversation: conversation)

    fetch_holder = { result: nil }
    fetch_reply = lambda do
      fetch_holder[:result] = if resolution[:blocked]
                                { reply: resolution[:message], stream_id: nil }
                              else
                                FourAy::Service.fetch_reply(
                                  message.content,
                                  conversation_id: message.conversation_id,
                                  agent_id: resolution[:agent_id],
                                  conversation: conversation
                                )
                              end
    end

    if inbox.web_widget?
      FourAy::TypingBroadcast.around_ai_reply(conversation, &fetch_reply)
    else
      fetch_reply.call
    end

    fetch_result = fetch_holder[:result] || { reply: nil, stream_id: nil }
    reply_text = fetch_result[:reply]
    stream_id = fetch_result[:stream_id]
    return if reply_text.blank?

    sender = bot_sender_for(conversation.inbox)
    return if sender.blank?

    content_attributes = {}
    content_attributes['four_ay_stream_id'] = stream_id if stream_id.present?

    conversation.messages.create!(
      content: reply_text,
      message_type: :outgoing,
      account_id: conversation.account_id,
      inbox_id: conversation.inbox_id,
      sender: sender,
      content_attributes: content_attributes
    )
  end

  def bot_sender_for(inbox)
    inbox.agent_bot || AgentBot.accessible_to(inbox.account).first
  end
end
