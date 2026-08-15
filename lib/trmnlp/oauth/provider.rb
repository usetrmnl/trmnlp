# frozen_string_literal: true

module TRMNLP
  module OAuth
    # Provider definition from the flat oauth_* keys in src/settings.yml (which
    # round-trip through push/pull). Credentials stay local and env-first so
    # they are never synced or committed.
    class Provider
      ENV_CLIENT_ID = 'TRMNL_OAUTH_CLIENT_ID'
      ENV_CLIENT_SECRET = 'TRMNL_OAUTH_CLIENT_SECRET'

      def initialize(settings, env: ENV)
        @settings = settings || {}
        @env = env
      end

      def authorize_url = settings['oauth_authorize_url']
      def token_url = settings['oauth_token_url']
      def refresh_url = settings['oauth_refresh_url'] || token_url
      def scopes = settings['oauth_scopes']
      def scope_separator = settings['oauth_scope_separator'] || ' '
      def pkce? = truthy?(settings['oauth_pkce_enabled'])
      def enabled? = truthy?(settings['oauth_enabled'])
      def client_id = env_first(ENV_CLIENT_ID, settings['oauth_client_id'])
      def client_secret = env_first(ENV_CLIENT_SECRET, settings['oauth_client_secret'])

      def configured?
        return false unless enabled? && authorize_url && token_url && client_id

        pkce? || present?(client_secret)
      end

      private

      attr_reader :settings, :env

      def truthy?(value) = [true, 'true'].include?(value)

      def env_first(key, fallback)
        value = env[key]
        present?(value) ? value : fallback
      end

      def present?(value) = !value.nil? && !value.empty?
    end
  end
end
