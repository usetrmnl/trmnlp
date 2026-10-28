# frozen_string_literal: true

require 'fileutils'

require_relative 'base'
require_relative '../browser_pool'
require_relative '../firefox_driver'
require_relative '../screen_generator'
require_relative '../screenshot'
require_relative '../testing/asset_cache'

module TRMNLP
  module Commands
    class Build < Base
      Options = Data.define(:dir, :quiet, :png, :width, :height, :color_depth, :bundle_assets, :palette) do
        def initialize(bundle_assets: false, palette: nil, **) = super(**, bundle_assets:, palette:)
      end

      def call
        context.validate!
        report_form_field_warnings
        report_framework_version_warning
        context.poller.poll_data
        context.paths.create_build_dir

        Screen.all.each { |screen| build_screen(screen) }

        reporter.info 'Done!'
      ensure
        @browser_pool&.shutdown
        @asset_cache&.stop
      end

      private

      def build_screen(screen)
        html = context.renderer.render_full_page(screen.name)
        overrides = context.config.project.asset_overrides
        built = if options.bundle_assets && overrides.any?
                  asset_cache.rewrite(html, overrides:,
                                            bundle_dir: context.paths.build_dir)
                else
                  html
                end
        write_html(screen.name, built)
        preview = options.png && overrides.any? ? asset_cache.rewrite(html, overrides:) : html
        write_png(screen.name, preview) if options.png
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
                                  height: options.height, color_depth: options.color_depth, palette_id: options.palette)
      end

      def screenshot = @screenshot ||= Screenshot.new(pool: browser_pool)

      def asset_cache
        @asset_cache ||= Testing::AssetCache.new(dir: context.paths.cache_dir.join('assets')).start
      end

      def browser_pool
        @browser_pool ||= BrowserPool.new(driver_factory: FirefoxDriver.method(:build))
      end
    end
  end
end
