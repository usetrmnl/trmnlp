# frozen_string_literal: true

require_relative 'screenshot'
require_relative 'image_quantizer'

module TRMNLP
  class ScreenGenerator
    # TRMNL's own copies (Converter::Preprocessor); the CDN refuses a page with no Referer.
    CHART_LIBRARIES = {
      'https://code.highcharts.com/highcharts.js' => 'https://trmnl.com/js/highcharts/12.3.0/highcharts.js',
      'https://code.highcharts.com/12.3.0/highcharts.js' => 'https://trmnl.com/js/highcharts/12.3.0/highcharts.js',
      'https://cdn.jsdelivr.net/npm/chartkick@5.0.1/dist/chartkick.min.js' => 'https://trmnl.com/js/chartkick/5.0.1/chartkick.min.js',
      'https://code.highcharts.com/highcharts-more.js' => 'https://trmnl.com/js/highcharts/12.3.0/highcharts-more.js',
      'https://code.highcharts.com/12.3.0/highcharts-more.js' => 'https://trmnl.com/js/highcharts/12.3.0/highcharts-more.js',
      'https://code.highcharts.com/modules/pattern-fill.js' => 'https://trmnl.com/js/highcharts/12.3.0/pattern-fill.js',
      'https://code.highcharts.com/12.3.0/modules/pattern-fill.js' => 'https://trmnl.com/js/highcharts/12.3.0/pattern-fill.js'
    }.freeze

    def initialize(html, opts = {})
      @input = html
      @screenshot = opts[:screenshot]
      @requested_width = opts[:width]
      @requested_height = opts[:height]
      @requested_color_depth = opts[:color_depth]
    end

    # The page as it is shown: chart libraries swapped for TRMNL's copies.
    def html = CHART_LIBRARIES.reduce(@input) { |page, (from, to)| page.gsub(from, to) }

    def process
      output = @screenshot.call(html:, width:, height:)
      ImageQuantizer.new(depth: color_depth, dither: @input.include?('image-dither')).call(output.path)
      output
    end

    def width = @requested_width || 800
    def height = @requested_height || 480

    private

    def color_depth
      return @requested_color_depth if @requested_color_depth
      return ::Regexp.last_match(1).to_i if @input&.match(/screen--(\d+)bit/)

      1
    end
  end
end
