require_relative 'base'

module TRMNLP
  module Commands
    class Login < Base
      def call
        puts "Please visit #{config.app.account_uri} to grab your API key, then paste it here."
        
        print "API Key: "
        api_key = STDIN.gets.chomp
        if api_key.empty?
          puts "API key cannot be empty."
          exit 1
        end
        
        config.app.api_key = api_key
        config.app.save
        
        puts "Saved changes to #{paths.app_config}"
      end
    end
  end
end