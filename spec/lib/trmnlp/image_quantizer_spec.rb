# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/image_quantizer'

RSpec.describe TRMNLP::ImageQuantizer do
  subject(:quantizer) { described_class.new(depth:, dither:) }

  let(:tool) { FakeMagick.new }
  let(:tmp_file) { instance_double(Tempfile, path: '/tmp/mono.png', close: nil) }
  let(:depth) { 2 }
  let(:dither) { false }

  class FakeMagick
    attr_reader :calls, :inputs

    def initialize
      @calls = []
      @inputs = []
    end

    def <<(arg) = @inputs << arg

    %i[alpha colorspace colors define depth dither monochrome posterize remap strip type].each do |verb|
      define_method(verb) { |arg = nil| @calls << [verb, arg].compact }
    end
  end

  before do
    allow(Tempfile).to receive(:new).and_return(tmp_file)
    allow(FileUtils).to receive(:mv)
    allow(MiniMagick).to receive(:convert).and_yield(tool)
    quantizer.call('/tmp/screenshot.png')
  end

  describe '#call' do
    it 'streams source then destination paths to ImageMagick' do
      expect(tool.inputs).to eq(['/tmp/screenshot.png', '/tmp/mono.png'])
    end

    it 'writes a palette PNG at the requested depth' do
      expect(tool.calls.last(5)).to eq([[:alpha, 'off'], [:depth, 2], [:type, 'Palette'],
                                        [:define, 'png:compression-level=9'], [:strip]])
    end

    it 'moves the quantized tmp file over the original path' do
      expect(FileUtils).to have_received(:mv).with('/tmp/mono.png', '/tmp/screenshot.png', force: true)
    end
  end

  context 'without dither at depth 1' do
    let(:depth) { 1 }

    it 'thresholds to two colors' do
      expect(tool.calls.first(2)).to eq([[:monochrome], [:colors, 2]])
    end
  end

  context 'without dither at depth 2' do
    it 'posterizes to four grays without dithering' do
      expect(tool.calls.first(3)).to eq([[:colorspace, 'Gray'], [:dither, 'None'], [:posterize, 4]])
    end
  end

  context 'with dither at depth 1' do
    let(:depth) { 1 }
    let(:dither) { true }

    it 'remaps to a halftone pattern with Floyd-Steinberg' do
      expect(tool.calls.first(2)).to eq([[:dither, 'FloydSteinberg'], [:remap, 'pattern:gray50']])
    end
  end

  context 'with dither at depth 2' do
    let(:dither) { true }

    it 'posterizes to four grays with Floyd-Steinberg' do
      expect(tool.calls.first(3)).to eq([[:colorspace, 'Gray'], [:dither, 'FloydSteinberg'], [:posterize, 4]])
    end
  end

  context 'with dither at depth 8' do
    let(:depth) { 8 }
    let(:dither) { true }

    it 'converts to grayscale only' do
      expect(tool.calls.first).to eq([:type, 'Grayscale'])
    end
  end

  context 'when depth exceeds 8' do
    let(:depth) { 99 }

    it 'clamps to 8' do
      expect(tool.calls).to include([:depth, 8])
    end
  end

  context 'when depth is below 1' do
    let(:depth) { 0 }

    it 'clamps to 1' do
      expect(tool.calls).to include([:depth, 1])
    end
  end
end
