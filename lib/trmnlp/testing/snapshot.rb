# frozen_string_literal: true

require 'fileutils'
require 'mini_magick'
require 'rbconfig'

module TRMNLP
  module Testing
    # A screen's PNG compared with the one stored for it. Fonts render differently per operating system,
    # so each keeps its own copy; run tests in the trmnlp Docker image for snapshots CI can share.
    class Snapshot
      UPDATE_ENV_KEY = 'TRMNLP_UPDATE_SNAPSHOTS'

      attr_reader :path

      def initialize(screen, name:, dir:)
        @screen = screen
        @path = File.join(dir, operating_system, "#{name}.png")
      end

      # nil when they match (or the stored copy was just written), otherwise why not.
      def mismatch
        return store if ENV[UPDATE_ENV_KEY] || (!File.exist?(path) && !ENV['CI'])
        return "no snapshot at #{path}; run `trmnlp test --update` to create it" unless File.exist?(path)

        differing = differing_pixels
        "#{differing} pixels differ from #{path}; run `trmnlp test --update` if the change is intended" if differing
      end

      private

      attr_reader :screen

      def store
        FileUtils.mkdir_p(File.dirname(path))
        FileUtils.cp(screen.png_path, path)
        nil
      end

      def differing_pixels
        expected = MiniMagick::Image.open(path)
        actual = MiniMagick::Image.open(screen.png_path)
        return 'all' unless expected.dimensions == actual.dimensions

        tool = MiniMagick::Tool.new('compare', errors: false)
        tool << '-metric' << 'AE' << path << screen.png_path << 'null:'
        count = nil
        tool.call { |_stdout, stderr, _status| count = stderr.to_f.round }
        count.positive? ? count : nil
      end

      def operating_system = RbConfig::CONFIG['host_os'][/darwin|linux|mswin|mingw/] || 'other'
    end
  end
end
