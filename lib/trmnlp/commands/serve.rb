# frozen_string_literal: true

require 'selenium-webdriver'

require_relative 'base'
require_relative '../api_client'
require_relative '../browser_pool'

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
        App.set(:browser_pool, BrowserPool.new(driver_factory: method(:build_firefox_driver)))
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

      def build_firefox_driver
        options = Selenium::WebDriver::Firefox::Options.new
        options.add_argument('--headless')
        options.add_argument('--disable-web-security')
        # Disable subpixel antialiasing — its colour fringing quantizes badly on 1-bit e-ink.
        options.add_preference('gfx.text.disable-aa', true)
        options.add_preference('gfx.text.subpixel-position.force-disabled', true)
        Selenium::WebDriver.for(:firefox, options: options).tap do |driver|
          driver.manage.window.maximize
        end
      end
    end
  end
end
