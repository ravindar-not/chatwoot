# frozen_string_literal: true

module InboundEmailVerification
  # Only when the inbox has +four_ay_db_verification_required+: prompts for email and sends a verify link
  # until contact custom_attributes['is_email_verified'] is true. Non–web-widget inboxes (WhatsApp, etc.).
  # The submitted email must return +found: true+ from +four_ay_lookup_api_url+ before a verification
  # email is sent; otherwise we ask for another email.
  class Handler
    ATTR_VERIFIED = 'is_email_verified'
    ATTR_PENDING_EMAIL = 'pending_verification_email'
    ATTR_LAST_MAIL_AT = 'wa_ev_last_mail_at'
    SYSTEM_FLAG_KEY = 'email_verification_system'

    def initialize(message)
      @message = message
    end

    def perform
      return unless @message.inbox.four_ay_db_verification_required?
      return unless feature_enabled?
      return unless applicable_incoming_message?

      contact = @message.sender
      return unless contact.is_a?(Contact)

      return if email_verified?(contact)

      email_candidate = extract_single_email(@message.content)


      if email_candidate.present?
        process_email_submission(contact, email_candidate)
      else
        send_verification_prompt
      end
    end

    class << self
      def email_verified?(contact)
        return false if contact.blank?

        ActiveModel::Type::Boolean.new.cast(contact.custom_attributes.stringify_keys[ATTR_VERIFIED])
      end

      def feature_enabled?
        raw = ENV['ENABLE_INBOUND_EMAIL_VERIFICATION'].presence ||
              ENV['ENABLE_WHATSAPP_EMAIL_VERIFICATION'].presence ||
              'false'
        ActiveModel::Type::Boolean.new.cast(raw)
      end
    end

    private

    def feature_enabled?
      self.class.feature_enabled?
    end

    def applicable_incoming_message?
      m = @message
      m.incoming? && !m.private? && m.content_type == 'text' && m.content.present? &&
        !m.inbox.web_widget?
    end

    def email_verified?(contact)
      self.class.email_verified?(contact)
    end

    def extract_single_email(content)
      stripped = content.to_s.strip
      return nil if stripped.blank?
      return nil if stripped.include?("\n") || stripped.include?("\r")

      return nil unless stripped.match?(Devise.email_regexp)

      stripped.downcase
    end

    def process_email_submission(contact, email)
      case lookup_email_resolution(contact, email)
      when :misconfigured
        send_outgoing(I18n.t('four_ay.errors.lookup_url_not_configured'))
        return
      when :lookup_error
        send_outgoing(I18n.t('four_ay.errors.lookup_failed'))
        return
      when :not_found
        send_outgoing(I18n.t('inbound_email_verification.messages.email_not_in_system'))
        return
      end
      # :ok — email is recognized (found: true); continue to send verification mail

      return if mail_cooldown_active?(contact)

      token = TokenService.generate(contact_id: contact.id, email: email)
      verify_url = build_verify_url(token)
      EmailVerificationMailer.with(
        account: contact.account,
        contact: contact,
        inbox: @message.inbox
      ).verification_email(
        email: email,
        verify_url: verify_url
      ).deliver_later

      merge_custom_attributes(contact, {
                                 ATTR_PENDING_EMAIL => email,
                                 ATTR_LAST_MAIL_AT => Time.zone.now.iso8601
                               })

      send_outgoing(
        I18n.t('inbound_email_verification.messages.check_inbox')
      )
    end

    def send_verification_prompt
      send_outgoing(
        I18n.t('inbound_email_verification.messages.enter_email')
      )
    end

    # Uses the same FourAY lookup API as FourAy::InboxAgentResolution (POST JSON with +email+ and optional +phone_number+).
    # When +found+ is not true, we do not send a verification link; the user can submit another email.
    def lookup_email_resolution(contact, email)
      url = @message.inbox.four_ay_lookup_api_url.to_s.strip
      return :misconfigured if url.blank?

      phone = contact.phone_number.to_s.presence
      result = FourAy::AgentIdLookup.fetch(url: url, email: email, phone_number: phone)
      return :lookup_error if result[:error].present?

      found = ActiveModel::Type::Boolean.new.cast(result[:found])
      found ? :ok : :not_found
    end

    def mail_cooldown_active?(contact)
      last = contact.custom_attributes.stringify_keys[ATTR_LAST_MAIL_AT]
      return false if last.blank?

      Time.zone.parse(last) > mail_cooldown_seconds.seconds.ago
    rescue ArgumentError, TypeError
      false
    end

    def mail_cooldown_seconds
      raw = ENV['INBOUND_EMAIL_VERIFICATION_MAIL_COOLDOWN_SECONDS'].presence ||
            ENV['WHATSAPP_EMAIL_VERIFICATION_MAIL_COOLDOWN_SECONDS'].presence ||
            '120'
      raw.to_i.clamp(60, 3600)
    end

    def build_verify_url(token)
      base = ENV.fetch('FRONTEND_URL', '').to_s.chomp('/')
      "#{base}/public/email_verifications/verify?token=#{CGI.escape(token)}"
    end

    def merge_custom_attributes(contact, attrs)
      merged = contact.custom_attributes.stringify_keys.merge(attrs.stringify_keys)
      contact.update!(custom_attributes: merged)
    end

    def send_outgoing(body)
      conversation = @message.conversation
      sender = bot_sender_for(conversation.inbox)
      
      return if sender.blank?

      conversation.messages.create!(
        account_id: conversation.account_id,
        inbox_id: conversation.inbox_id,
        message_type: :outgoing,
        content: body,
        private: false,
        content_type: :text,
        sender: sender,
        content_attributes: { SYSTEM_FLAG_KEY => true }
      )
    end

    def bot_sender_for(inbox)
      inbox.agent_bot || AgentBot.accessible_to(inbox.account).first
    end
  end
end
