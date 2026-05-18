# frozen_string_literal: true

require 'fileutils'

require_relative 'base'
require_relative '../browser_pool'
require_relative '../firefox_driver'
require_relative '../screen_generator'
require_relative '../screenshot'

module TRMNLP
  module Commands
    class Build < Base
      Options = Data.define(:dir, :quiet, :png, :width, :height, :color_depth)

      def call
        context.validate!
        report_form_field_warnings
        context.poller.poll_data
        context.paths.create_build_dir

        Screen.all.each { |screen| build_screen(screen) }

        reporter.info 'Done!'
      ensure
        @browser_pool&.shutdown
      end

      private

      def build_screen(screen)
        html = context.renderer.render_full_page(screen.name)
        write_html(screen.name, html)
        write_png(screen.name, html) if options.png
      end

      def write_html(view, html)
        path = context.paths.build_dir.join("#{view}.html")
        reporter.info "Writing #{path}..."
        path.write(html)
      end

      # --png is additive: the HTML is rendered either way, so it stays on
      # disk alongside the PNG rather than being replaced by it.
      def write_png(view, html)
        path = context.paths.build_dir.join("#{view}.png")
        reporter.info "Writing #{path}..."
        image = screen_generator(html).process
        FileUtils.cp(image.path, path)
      ensure
        image&.close!
      end

      # --width/--height/--color-depth are optional; nil lets ScreenGenerator
      # fall back to 800x480 and the screen--Nbit depth sniffed from the markup.
      def screen_generator(html)
        ScreenGenerator.new(html, screenshot:, width: options.width,
                                  height: options.height, color_depth: options.color_depth)
      end

      def screenshot = @screenshot ||= Screenshot.new(pool: browser_pool)

      def browser_pool
        @browser_pool ||= BrowserPool.new(driver_factory: FirefoxDriver.method(:build))
      end
    end
  end
end
