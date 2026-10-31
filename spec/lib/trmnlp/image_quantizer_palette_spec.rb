# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/image_quantizer'
require 'mini_magick'

# Runs the real ImageMagick: a fake would not show which colors reach the file.
RSpec.describe TRMNLP::ImageQuantizer, 'with a color palette' do
  let(:bwry) { %w[#000000 #FF0000 #FFFFFF #FFFF00] }
  let(:dir) { Dir.mktmpdir }
  let(:path) { File.join(dir, 'shot.png') }

  before do
    # Red-to-blue gradient plus a green block: many colors, none of them all in the palette.
    MiniMagick.convert do |m|
      m << '-size' << '64x32' << 'gradient:red-blue' << '-fill' << '#33aa55' << '-draw' << 'rectangle 0,0 20,10' << path
    end
  end

  after { FileUtils.remove_entry(dir) }

  def colors(file)
    out = MiniMagick.convert { |m| m << file << '-unique-colors' << '-depth' << '8' << 'txt:-' }
    out.scan(/#[0-9A-F]{6}/).uniq.sort
  end

  def png_type(file) = MiniMagick::Tool.new('identify') { |m| m << '-format' << '%[type]' << file }

  [false, true].each do |dither|
    it "keeps only the palette colors, #{dither ? 'dithered' : 'flat'}" do
      described_class.new(depth: 1, dither:, palette: bwry).call(path)

      expect(colors(path) - bwry.map(&:upcase)).to be_empty
      expect(colors(path)).to include('#FF0000')
    end
  end

  it 'writes an indexed PNG' do
    described_class.new(depth: 1, dither: false, palette: bwry).call(path)

    expect(png_type(path)).to eq('Palette')
  end

  it 'leaves no gray steps behind for a 6-color palette' do
    six = %w[#FF0000 #00FF00 #0000FF #FFFF00 #000000 #FFFFFF]
    described_class.new(depth: 1, dither: false, palette: six).call(path)

    expect(colors(path) - six).to be_empty
    expect(colors(path)).to include('#FF0000', '#00FF00')
  end

  it 'renders a gray palette (nil or empty) the same as before' do
    other = File.join(dir, 'other.png')
    FileUtils.cp(path, other)
    described_class.new(depth: 2, dither: false).call(path)
    described_class.new(depth: 2, dither: false, palette: []).call(other)

    expect(File.binread(other)).to eq(File.binread(path))
    expect(colors(path).size).to be <= 4
  end
end
