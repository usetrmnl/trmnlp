# frozen_string_literal: true

require 'securerandom'
require 'digest'
require 'base64'

module TRMNLP
  module OAuth
    # Proof Key for Code Exchange (RFC 7636, S256).
    module Pkce
      module_function

      def verifier = SecureRandom.urlsafe_base64(64)

      def challenge(verifier)
        Base64.urlsafe_encode64(Digest::SHA256.digest(verifier), padding: false)
      end
    end
  end
end
