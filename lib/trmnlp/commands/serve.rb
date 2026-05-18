# frozen_string_literal: true

require_relative 'base'
require_relative '../api_client'
require_relative '../browser_pool'
require_relative '../firefox_driver'

module TRMNLP
  module Commands
    class Serve < Base
      Options = Data.define(:dir, :quiet, :bind, :port)

      def call
        context.validate!
        report_form_field_warnings

        # Must come AFTER parsing options
        require_relative '../app'

        # Now we can configure things
        App.set(:context, context)
        App.set(:browser_pool, BrowserPool.new(driver_factory: FirefoxDriver.method(:build)))
        App.set(:bind, options.bind)
        App.set(:port, options.port)
        permit_all_hosts if codespaces?

        # Finally, start the app!
        App.run!
      end

      private

      # Codespaces forwards the dev port through a proxy whose Host header Sinatra rejects.
      def codespaces? = ENV['CODESPACES'] == 'true'

      def permit_all_hosts
        App.set(:host_authorization, { allow_if: ->(_env) { true } })
      end
    end
  end
end
