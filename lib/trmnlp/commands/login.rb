require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Login < Base
      def call
        if config.app.logged_in?
          anonymous_key = config.app.api_key[0..10] + '*' * (config.app.api_key.length - 11)
          output "Currently authenticated as: #{anonymous_key}"
          confirm = prompt("You are already authenticated. Do you want to re-authenticate? (y/N): ")
          return unless confirm.strip.downcase == 'y'
        end

        output "Please visit #{config.app.account_uri} to grab your API key, then paste it here."
        
        api_key = prompt("API Key: ")
        raise Error, "API key cannot be empty" if api_key.empty?
        raise Error, "Invalid API key; did you copy it from the right place?" unless api_key.start_with?("user_")
        
        config.app.api_key = api_key

        api_client = APIClient.new(config)
        begin
          user_info = api_client.get_me
          output "Authenticated as #{user_info['name']} (#{user_info['email']})"
          config.app.save
          output "Saved changes to #{paths.app_config}"
        rescue => e
          raise Error, "Authentication failed; changes were not saved.\n#{e.message}"
        end
      end
    end
  end
end