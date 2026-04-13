# frozen_string_literal: true

module InboundEmailVerification
  # Signed tokens for email verification links (contact_id + email + expiry; link valid 10 minutes).
  class TokenService
    class << self
      def generate(contact_id:, email:)
        payload = {
          'contact_id' => contact_id,
          'email' => email.to_s.downcase.strip,
          'exp' => 10.minutes.from_now.to_i
        }
        verifier.generate(payload)
      end

      def decode(token)
        data = verifier.verify(token)
        return nil if data['exp'].to_i < Time.zone.now.to_i

        data
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        nil
      end

      private

      def verifier
        # Salt unchanged so tokens issued before the rename keep validating.
        @verifier ||= ActiveSupport::MessageVerifier.new(
          Rails.application.key_generator.generate_key('whatsapp-email-verification'),
          digest: 'SHA256',
          serializer: JSON
        )
      end
    end
  end
end
