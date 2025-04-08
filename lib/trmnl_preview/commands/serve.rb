require 'zip'

require_relative 'base'
require_relative '../api_client'

module TRMNLPreview
  module Commands
    class Serve < Base
      def call
        # Must come AFTER parsing options
        require_relative '../app'

        # Now we can configure things
        App.set(:root_dir, options.dir)
        App.set(:bind, options.bind)
        App.set(:port, options.port)

        # Finally, start the app!
        App.run!
      end
    end
  end
end