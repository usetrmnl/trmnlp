# frozen_string_literal: true

require 'mini_magick'
require 'tempfile'
require 'fileutils'

module TRMNLP
  class ImageQuantizer
    MIN_DEPTH = 1
    MAX_DEPTH = 8

    def initialize(depth:)
      @depth = clamp(depth)
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
        m.colorspace 'Gray'
        m.dither 'FloydSteinberg'
        apply_depth(m)
        m.depth @depth
        m.define "png:bit-depth=#{@depth}"
        m.strip
        m << dst
      end
    end

    def apply_depth(m)
      if @depth == 1
        # NOTE: 1-bit only has black/white, so a halftone remap simulates gray
        # via dithering patterns. Skipping this collapses photos to pure
        # silhouettes.
        m.remap 'pattern:gray50'
        m.posterize 2
        m.colors 2
        m.type 'Bilevel'
      else
        levels = 2**@depth
        m.posterize levels
        m.colors levels
      end
    end

    def clamp(depth)
      [[depth.to_i, MIN_DEPTH].max, MAX_DEPTH].min
    end
  end
end
