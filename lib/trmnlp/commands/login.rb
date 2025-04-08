require_relative 'base'

module TRMNLP
  module Commands
    class Login < Base
      def call
        if config.app.logged_in?
          anonymous_key = config.app.api_key[0..10] + '*' * (config.app.api_key.length - 11)
          puts "Currently authenticated as: #{anonymous_key}" 
        end

        puts "Please visit #{config.app.account_uri} to grab your API key, then paste it here."
        
        print "API Key: "
        api_key = STDIN.gets.chomp
        raise Error, "API key cannot be empty" if api_key.empty?
        
        config.app.api_key = api_key
        config.app.save
        
        puts "Saved changes to #{paths.app_config}"
      end
    end
  end
end