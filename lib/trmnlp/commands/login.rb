# frozen_string_literal: true

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Login < Base
      Options = Data.define(:dir, :quiet, :server)

      def call
        config.app.base_url = options.server if options.server

        if config.app.logged_in?
          anonymous_key = config.app.api_key[0..10] + ('*' * (config.app.api_key.length - 11))
          reporter.info "Currently authenticated as: #{anonymous_key}"
          confirm = prompt('You are already authenticated. Do you want to re-authenticate? (y/N): ')
          return unless confirm.strip.downcase == 'y'
        end

        reporter.info "Please visit #{config.app.account_uri} to grab your API key, then paste it here."

        api_key = prompt('API Key: ')
        raise InvalidApiKey, 'API key cannot be empty' if api_key.empty?

        if config.app.base_uri.host.end_with?('trmnl.com')
          raise InvalidApiKey, 'Invalid API key; did you copy it from the right place?' unless api_key.start_with?('user_')
        end

        config.app.api_key = api_key

        api_client = APIClient.new(config)
        begin
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
end
