# frozen_string_literal: true

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Login < Base
      Options = Data.define(:dir, :quiet, :server)

      def call
        config.app.base_url = options.server if options.server
        return unless confirm_reauthentication?

        reporter.info "Please visit #{config.app.account_uri} to grab your API key, then paste it here."

        api_key = prompt('API Key: ')
        raise InvalidApiKey, 'API key cannot be empty' if api_key.empty?

        # Only trmnl.com issues user_-prefixed keys; BYOS servers use their own token formats (e.g. Sanctum).
        if config.app.trmnl_host? && !api_key.start_with?('user_')
          raise InvalidApiKey,
                'Invalid API key; did you copy it from the right place?'
        end

        config.app.api_key = api_key
        save_credentials
      end

      private

      def confirm_reauthentication?
        return true unless config.app.logged_in?

        anonymous_key = config.app.api_key[0..10] + ('*' * (config.app.api_key.length - 11))
        reporter.info "Currently authenticated as: #{anonymous_key}"
        confirm = prompt('You are already authenticated. Do you want to re-authenticate? (y/N): ')
        confirm.strip.downcase == 'y'
      end

      def save_credentials
        api_client = APIClient.new(config)
        user_info = api_client.get_me
        reporter.info "Authenticated as #{user_info['name']} (#{user_info['email']})"
        config.app.save
        reporter.info "Saved changes to #{paths.app_config}"
      rescue StandardError => e
        raise AuthenticationFailed, "Authentication failed; changes were not saved.\n#{e.message}"
      end
    end
  end
end
