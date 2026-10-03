# frozen_string_literal: true

require 'mini_magick'
require 'tempfile'
require 'fileutils'

module TRMNLP
  # TRMNL's Converter::MagickWrapper steps: a page dithers only when it asks for `image-dither`.
  class ImageQuantizer
    MIN_DEPTH = 1
    MAX_DEPTH = 8

    def initialize(depth:, dither:)
      @depth = clamp(depth)
      @dither = dither
    end

    def call(path)
      tmp = Tempfile.new(['mono', '.png'])
      tmp.close
      quantize(path, tmp.path)
      FileUtils.mv(tmp.path, path, force: true)
    end

    private

    def quantize(src, dst)
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
