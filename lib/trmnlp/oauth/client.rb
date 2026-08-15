# frozen_string_literal: true

require 'oauth2'
require 'uri'

module TRMNLP
  module OAuth
    class Client
      def initialize(provider)
        @provider = provider
      end

      def authorize_url(redirect_uri:, state:, code_challenge: nil)
        params = { redirect_uri:, scope: provider.scopes, state: }
        params.merge!(code_challenge:, code_challenge_method: 'S256') if code_challenge
        oauth_client(provider.token_url).auth_code.authorize_url(**params)
      end

      def exchange_code(code:, redirect_uri:, code_verifier: nil)
        params = { redirect_uri: }
        params[:code_verifier] = code_verifier if code_verifier
        bundle oauth_client(provider.token_url).auth_code.get_token(code, params)
      end

      def refresh(refresh_token:)
        client = oauth_client(provider.refresh_url)
        bundle OAuth2::AccessToken.new(client, nil, refresh_token:).refresh!
      end

      private

      attr_reader :provider

      def oauth_client(token_url)
        OAuth2::Client.new(
          provider.client_id, provider.client_secret,
          site: origin(token_url), authorize_url: provider.authorize_url,
          token_url:, auth_scheme:
        )
      end

      # A PKCE public client has no secret, so its client_id must travel in the
      # request body; a confidential client authenticates with HTTP Basic.
      def auth_scheme = provider.client_secret ? :basic_auth : :request_body

      # oauth2 posts tokens through a connection built from the site, so give it
      # the endpoint's origin even though the full URL is absolute.
      def origin(url)
        uri = URI(url)
        port = uri.port == uri.default_port ? nil : ":#{uri.port}"
        "#{uri.scheme}://#{uri.host}#{port}"
      end

      def bundle(token)
        TokenBundle.new(
          access_token: token.token,
          refresh_token: token.refresh_token,
          expires_at: token.expires_at,
          token_type: token.params['token_type'] || 'Bearer'
        )
      end
    end
  end
end
