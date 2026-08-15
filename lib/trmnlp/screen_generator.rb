# frozen_string_literal: true

require_relative 'screenshot'
require_relative 'image_quantizer'

module TRMNLP
  class ScreenGenerator
    def initialize(html, opts = {})
      @input = html
      @screenshot = opts[:screenshot]
      @requested_width = opts[:width]
      @requested_height = opts[:height]
      @requested_color_depth = opts[:color_depth]
    end

    def process
      output = @screenshot.call(html: @input, width:, height:)
      ImageQuantizer.new(depth: color_depth).call(output.path)
      output
    end

    private

    def width = @requested_width || 800
    def height = @requested_height || 480

    def color_depth
      return @requested_color_depth if @requested_color_depth
      return ::Regexp.last_match(1).to_i if @input&.match(/screen--(\d+)bit/)

      1
    end
  end
end
