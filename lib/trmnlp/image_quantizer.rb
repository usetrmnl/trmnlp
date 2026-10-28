# frozen_string_literal: true

require 'mini_magick'
require 'tempfile'
require 'fileutils'

module TRMNLP
  # TRMNL's Converter::MagickWrapper steps: a page dithers only when it asks for `image-dither`.
  class ImageQuantizer
    MIN_DEPTH = 1
    MAX_DEPTH = 8

    # palette: hex colors of a color panel (TRMNL's /api/palettes `colors`); nil or empty keeps the gray steps.
    # channel_bits: for the `screen--color-full` palettes only; 8 keeps the render lossless (color-24bit),
    # 4 posterizes each channel to 16 levels, 4096 colors (color-12bit).
    def initialize(depth:, dither:, palette: nil, channel_bits: nil)
      @depth = clamp(depth)
      @dither = dither
      @palette = Array(palette)
      @channel_bits = channel_bits
    end

    def call(path)
      tmp = Tempfile.new(['mono', '.png'])
      tmp.close
      quantize(path, tmp.path)
      FileUtils.mv(tmp.path, path, force: true)
    end

    private

    def quantize(src, dst)
      return quantize_full_color(src, dst) if @channel_bits
      return quantize_to_palette(src, dst) unless @palette.empty?

      MiniMagick.convert do |m|
        m << src
        @dither ? quantize_with_dither(m) : quantize_without_dither(m)
        m.alpha 'off'
        m.depth @depth
        m.type 'Palette'
        m.define 'png:compression-level=9'
        m.strip
        m << dst
      end
    end

    def quantize_full_color(src, dst)
      MiniMagick.convert do |m|
        m << src
        if @channel_bits < 8
          m.dither(@dither ? 'FloydSteinberg' : 'None')
          m.posterize 2**@channel_bits
        end
        m.alpha 'off'
        m.define 'png:compression-level=9'
        m.strip
        m << dst
      end
    end

    # TRMNL's color steps (DIY ImageMagick guide): every pixel mapped to the panel's colors, indexed PNG out.
    def quantize_to_palette(src, dst)
      MiniMagick.convert do |m|
        m << src
        if @dither
          m.normalize
          m.modulate '110,150'
          m.colorspace 'RGB'
        end
        add_palette_image(m)
        m.dither(@dither ? 'FloydSteinberg' : 'None')
        m.remap 'mpr:palette'
        m.colorspace 'sRGB' if @dither
        m.alpha 'off'
        m.type 'Palette'
        m.define 'png:compression-level=9'
        m.strip
        m << dst
      end
    end

    def add_palette_image(m)
      m << '(' << '-size' << '1x1'
      @palette.each { m << "xc:#{it}" }
      m << '+append' << '+write' << 'mpr:palette' << '+delete' << ')'
    end

    def quantize_without_dither(m)
      if @depth == 1
        m.monochrome
        m.colors 2
      else
        m.colorspace 'Gray'
        m.dither 'None'
        m.posterize gray_level_count
      end
    end

    def quantize_with_dither(m)
      case @depth
      when 1
        m.dither 'FloydSteinberg'
        m.remap 'pattern:gray50'
      when 8
        m.type 'Grayscale'
      else
        m.colorspace 'Gray'
        m.dither 'FloydSteinberg'
        m.posterize gray_level_count
      end
    end

    def gray_level_count = 2**@depth

    def clamp(depth)
      [[depth.to_i, MIN_DEPTH].max, MAX_DEPTH].min
    end
  end
end
