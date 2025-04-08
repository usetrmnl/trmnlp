require 'zip'

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Serve < Base
      def call
        # Must come AFTER parsing options
        require_relative '../app'

        # Now we can configure things
        App.set(:context, context)
        App.set(:bind, options.bind)
        App.set(:port, options.port)

        # Finally, start the app!
        App.run!
      end
    end
  end
end