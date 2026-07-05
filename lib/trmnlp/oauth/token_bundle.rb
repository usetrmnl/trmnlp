# frozen_string_literal: true

module TRMNLP
  module OAuth
    TokenBundle = Data.define(:access_token, :refresh_token, :expires_at, :token_type) do
      def self.from_h(hash)
        new(
          access_token: hash['access_token'],
          refresh_token: hash['refresh_token'],
          expires_at: hash['expires_at'],
          token_type: hash['token_type'] || 'Bearer'
        )
      end

      def expired?
        return false unless expires_at

        # Treat as expired 5 minutes early so a token never dies mid-request.
        expires_at.to_i - 300 <= Time.now.to_i
      end

      # A refresh response often omits the rotated refresh_token (and sometimes
      # other fields); the prior values remain valid, so carry them forward.
      def merge_refresh(fresh)
        with(
          access_token: fresh.access_token,
          refresh_token: fresh.refresh_token || refresh_token,
          expires_at: fresh.expires_at || expires_at,
          token_type: fresh.token_type || token_type
        )
      end
    end
  end
end
