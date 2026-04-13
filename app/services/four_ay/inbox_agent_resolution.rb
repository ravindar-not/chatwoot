# frozen_string_literal: true

module FourAy
  # Resolves which 4AY agent_id to use from inbox settings and optional external lookup by contact email (+ phone).
  # Website widget inboxes never use external DB lookup; they always use the inbox +four_ay_agent_id+ only.
  class InboxAgentResolution
    class << self
      def call(inbox:, conversation:)
        new(inbox: inbox, conversation: conversation).call
      end
    end

    def initialize(inbox:, conversation:)
      @inbox = inbox
      @conversation = conversation
    end

    # @return [Hash] :agent_id (String or nil), or :blocked with :message when the AI reply must be skipped
    def call
      return { agent_id: inbox.four_ay_agent_id.to_s.presence } if inbox.web_widget?

      if inbox.four_ay_db_verification_required?
        resolve_via_lookup
      else
        { agent_id: inbox.four_ay_agent_id.to_s.presence }
      end
    end

    private

    attr_reader :inbox, :conversation

    def resolve_via_lookup
      url = inbox.four_ay_lookup_api_url.to_s.strip
      if url.blank?
        Rails.logger.error('FourAy::InboxAgentResolution: four_ay_lookup_api_url blank while DB verification is required')
        return blocked(I18n.t('four_ay.errors.lookup_url_not_configured'))
      end

      email = conversation.contact&.email.to_s.strip
      if email.blank?
        Rails.logger.warn('FourAy::InboxAgentResolution: no contact email for lookup')
        return blocked(I18n.t('four_ay.errors.email_required_for_lookup'))
      end

      phone = conversation.contact&.phone_number.to_s.presence
      result = AgentIdLookup.fetch(url: url, email: email, phone_number: phone)

      if result[:error].present?
        Rails.logger.error("FourAy::InboxAgentResolution lookup error: #{result[:error]}")
        return blocked(I18n.t('four_ay.errors.lookup_failed'))
      end

      if result[:found] && result[:four_ay_agent_id].present?
        { agent_id: result[:four_ay_agent_id].to_s }
      else
        blocked(I18n.t('four_ay.errors.email_not_registered'))
      end
    end

    def blocked(message)
      { blocked: true, message: message }
    end
  end
end
