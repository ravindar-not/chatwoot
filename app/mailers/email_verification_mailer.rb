# frozen_string_literal: true

class EmailVerificationMailer < ApplicationMailer
  # Use .with(account:, contact:, inbox:) so locale and @contact are available.
  # Optional EmailConfiguration on inbox overrides from/subject; body column reserved for future use.
  def verification_email(email:, verify_url:)
    @contact = params[:contact]
    @verify_url = verify_url
    @email = email
    @phone_display = @contact&.phone_number.presence ||
                      I18n.t('inbound_email_verification.mailer.phone_unavailable')
    inbox = params[:inbox]
    config = inbox&.email_configuration

    subject_line = config&.mail_subject.presence ||
                   I18n.t('inbound_email_verification.mailer.subject')
    from_line = config&.mail_from.presence ||
                ENV.fetch('MAILER_SENDER_EMAIL', 'Chatwoot <accounts@chatwoot.com>')

    mail(
      to: email,
      from: from_line,
      subject: subject_line
    )
  end
end
