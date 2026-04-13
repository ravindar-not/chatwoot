# frozen_string_literal: true

# Prompts for email / sends verification only when the inbox has four_ay_db_verification_required.
class EmailVerificationListener < BaseListener
  def message_created(event)
    message = extract_message_and_account(event)[0]
    InboundEmailVerification::Handler.new(message).perform
  end
end
