# frozen_string_literal: true

module TRMNLP
  module OAuth
    class Provider
      # Read ENV-first so the secret never lives in the committed .trmnlp.yml.
      ENV_CLIENT_SECRET = 'TRMNL_OAUTH_CLIENT_SECRET'

      def initialize(config, env: ENV)
        @config = config || {}
        @env = env
      end

      def authorize_url = config['authorize_url']
      def token_url = config['token_url']
      def refresh_url = config['refresh_url'] || token_url
      def scopes = config['scopes']
      def scope_separator = config['scope_separator'] || ' '
      def client_id = config['client_id']
      def pkce? = config['pkce'] == true

      def client_secret
        env_secret = env[ENV_CLIENT_SECRET]
        present?(env_secret) ? env_secret : config['client_secret']
      end

      def configured?
        return false unless authorize_url && token_url && client_id

        pkce? || present?(client_secret)
      end

      private

      attr_reader :config, :env

      def present?(value) = !value.nil? && !value.empty?
    end
  end
end
