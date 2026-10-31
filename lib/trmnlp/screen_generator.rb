# frozen_string_literal: true

require_relative 'screenshot'
require_relative 'image_quantizer'
require_relative 'testing/device_models'

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

    FULL_COLOR_CLASS = 'screen--color-full'

    def initialize(html, opts = {})
      @input = html
      @screenshot = opts[:screenshot]
      @requested_width = opts[:width]
      @requested_height = opts[:height]
      @requested_color_depth = opts[:color_depth]
      @requested_palette = opts[:palette]
      @palette_id = opts[:palette_id].to_s.then { it.empty? ? nil : it }
    end

    # The page as it is shown: chart libraries swapped for TRMNL's copies, laid out unscaled until the capture.
    def html
      CHART_LIBRARIES.reduce(@input) { |page, (from, to)| page.gsub(from, to) }
                     .sub('</head>', "#{Screenshot::LAYOUT_PASS_STYLE}</head>")
    end

    # The palette is resolved before the capture, so an unknown id fails without a render.
    def process
      options = quantizer_options
      output = @screenshot.call(html:, width:, height:)
      ImageQuantizer.new(**options).call(output.path)
      output
    end

    def width = @requested_width || 800
    def height = @requested_height || 480

    private

    def quantizer_options
      options = { depth: color_depth, dither: @input.include?('image-dither') }
      colors = palette
      options[:palette] = colors if colors
      options[:channel_bits] = channel_bits if channel_bits
      options
    end

    # Given, or the colors of the `screen--color-*` class in the markup (nil when offline: gray steps then).
    def palette
      return @requested_palette if @requested_palette
      return if channel_bits
      return trmnl_palette['colors'] if trmnl_palette

      framework_class = @input&.[](/screen--color-[\w-]+/)
      Testing::DeviceModels.colors_for_class(framework_class) if framework_class
    end

    # TRMNL's palette the id names; an id TRMNL does not have stops the render with the ids it has.
    def trmnl_palette
      return unless @palette_id

      @trmnl_palette ||= Testing::DeviceModels.palette_with_id(@palette_id)
    end

    # color-24bit (and the class alone) is lossless; color-12bit posterizes to 4 bits a channel.
    def channel_bits
      return 4 if @palette_id == 'color-12bit'

      8 if @palette_id == 'color-24bit' || (@palette_id.nil? && @input&.include?(FULL_COLOR_CLASS))
    end

    # A palette's gray count sets the depth, as the picker does; the color paths do not read it.
    def color_depth
      return 1 if channel_bits
      return Math.log2(trmnl_palette['grays']).ceil if trmnl_palette
      return @requested_color_depth if @requested_color_depth
      return ::Regexp.last_match(1).to_i if @input&.match(/screen--(\d+)bit/)

      1
    end
  end
end
