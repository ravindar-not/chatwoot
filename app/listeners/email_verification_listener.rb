# frozen_string_literal: true

# Prompts for email / sends verification only when the inbox has four_ay_db_verification_required.
# Skips website widget inboxes entirely (no verification mail flow).
class EmailVerificationListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    return if message.inbox.web_widget?

    InboundEmailVerification::Handler.new(message).perform
  end
end
