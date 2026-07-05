# frozen_string_literal: true

module TRMNLP
  module OAuth
    class RefreshError < StandardError; end

    class Session
      def initialize(provider:, token_store:, client:)
        @provider = provider
        @token_store = token_store
        @client = client
      end

      def configured? = provider.configured?

      def pkce? = provider.pkce?

      def connected?
        return false unless configured?

        stored = token_store.read
        !stored.nil? && !stored.access_token.nil?
      end

      def access_token = current_bundle&.access_token

      def liquid_variables
        return {} unless connected?

        bundle = current_bundle
        {
          'oauth_access_token' => bundle.access_token,
          'oauth_token_type' => bundle.token_type,
          'oauth_client_id' => provider.client_id
        }
      end

      def authorize_url(redirect_uri:, state:, code_challenge: nil)
        client.authorize_url(redirect_uri:, state:, code_challenge:)
      end

      def complete(code:, redirect_uri:, code_verifier: nil)
        token_store.write(client.exchange_code(code:, redirect_uri:, code_verifier:))
      end

      def disconnect = token_store.clear

      private

      attr_reader :provider, :token_store, :client

      # Returns the stored token, transparently refreshing and re-persisting it
      # when it is near expiry. nil when nothing is connected yet.
      def current_bundle
        stored = token_store.read
        return nil if stored.nil? || stored.access_token.nil?

        stored.expired? ? refreshed(stored) : stored
      end

      def refreshed(stale)
        token_store.write stale.merge_refresh(client.refresh(refresh_token: stale.refresh_token))
      rescue StandardError => e
        raise RefreshError, "OAuth token refresh failed: #{e.message}. Reconnect at /oauth/connect."
      end
    end
  end
end
