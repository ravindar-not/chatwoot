# frozen_string_literal: true

module Public
  # Public GET: user clicks link from verification email; marks contact as email-verified.
  class EmailVerificationsController < ActionController::Base
    layout false

    def show
      token = params[:token].to_s
      data = InboundEmailVerification::TokenService.decode(token)
      if data.blank?
        render plain: I18n.t('inbound_email_verification.verify.invalid_or_expired'), status: :unprocessable_entity
        return
      end

      contact = Contact.find_by(id: data['contact_id'])
      if contact.blank?
        render plain: I18n.t('inbound_email_verification.verify.contact_not_found'), status: :not_found
        return
      end

      email = data['email'].to_s
      attrs = contact.custom_attributes.stringify_keys
      attrs[InboundEmailVerification::Handler::ATTR_VERIFIED] = true
      attrs.delete(InboundEmailVerification::Handler::ATTR_PENDING_EMAIL)

      update_params = { custom_attributes: attrs }
      update_params[:email] = email if contact.email.blank?

      contact.update!(update_params)

      render plain: I18n.t('inbound_email_verification.verify.success')
    rescue ActiveRecord::RecordInvalid => e
      Rails.logger.error "[INBOUND_EMAIL_VERIFICATION] #{e.message}"
      render plain: I18n.t('inbound_email_verification.verify.failed'), status: :unprocessable_entity
    end
  end
end
