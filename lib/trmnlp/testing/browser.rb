# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'

require_relative '../browser_pool'
require_relative '../firefox_driver'
require_relative '../screen_generator'
require_relative '../screenshot'
require_relative 'inline_stylesheets'

module TRMNLP
  module Testing
    # The Firefox one example renders in, checked out of the pool on first use and back in by #release.
    # Pages load the way `trmnlp build --png` loads them, through ScreenGenerator and Screenshot.
    class Browser
      def initialize(pool:)
        @pool = pool
        @screenshot = Screenshot.new(pool:)
        @pages = {}.compare_by_identity
        @fresh_browsers = []
      end

      # A Firefox of its own, with nothing cached, closed when this browser is released.
      def fresh
        pool = BrowserPool.new(driver_factory: FirefoxDriver.method(:build), max_size: 1)
        self.class.new(pool:).tap { @fresh_browsers << [it, pool] }
      end

      # The PNG path, quantized to the device's bit depth like a build's.
      def capture(screen)
        @capturing = screen
        keep(generate(screen))
      end

      # ScreenGenerator's screenshot interface: html arrives with chart libraries swapped for TRMNL's copies.
      def call(html:, width:, height:)
        @pages[@capturing] = [html, width, height]
        show(@capturing)
        @screenshot.capture(driver)
      end

      # Yields the driver with screen's page loaded, reloading it if a later render replaced it.
      def on(screen)
        show(screen) unless @showing.equal?(screen)
        yield driver
      end

      def release
        @fresh_browsers.each do |browser, pool|
          browser.release
          pool.shutdown
        end
        @fresh_browsers.clear
        @pool.checkin(@driver) if @driver
        @driver = nil
        @showing = nil
      end

      private

      def generate(screen)
        device = screen.device
        html = InlineStylesheets.call(screen.html)
        ScreenGenerator.new(html, screenshot: self, width: device.width, height: device.height,
                                  color_depth: device.bit_depth).process
      end

      def driver = @driver ||= @pool.checkout

      def show(screen)
        html, width, height = @pages.fetch(screen)
        @screenshot.show(driver, html, width, height,
                         wait_for: screen.wait_for, wait_for_timeout: screen.wait_for_timeout)
        @showing = screen
      end

      def keep(image)
        path = File.join(Dir.mktmpdir('trmnlp-screen-'), 'screen.png')
        FileUtils.cp(image.path, path)
        path
      ensure
        image.close!
      end
    end
  end
end
