# frozen_string_literal: true

require 'mini_magick'

module TRMNLP
  module Testing
    # How many pixels of a PNG stand out from its background, the gray level most pixels have; area: a box
    # counts only inside it.
    class InkCount
      # Half the gray scale: text and lines pass; a faint tint or frame does not, on white or on black.
      MIN_DIFFERENCE = 128

      def initialize(path, area: nil)
        @path = path
        @area = area
      end

      def pixels
        levels = histogram
        return 0 if levels.empty?

        background = levels.max_by(&:last).first
        levels.sum { |level, count| (level - background).abs > MIN_DIFFERENCE ? count : 0 }
      end

      private

      # [gray level 0-255, pixel count] for each level the picture uses.
      def histogram
        output = MiniMagick.convert do |convert|
          convert << @path
          convert << '-crop' << crop_geometry << '+repage' if @area
          convert << '-colorspace' << 'gray' << '-depth' << '8' << '-format' << '%c' << 'histogram:info:-'
        end
        output.lines.filter_map do |line|
          (match = line.match(/\A\s*(\d+):\s*\(\s*(\d+)/)) && [match[2].to_i, match[1].to_i]
        end
      end

      def crop_geometry = "#{@area.width.round}x#{@area.height.round}+#{@area.left.round}+#{@area.top.round}"
    end
  end
end
