# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/image_quantizer'

RSpec.describe TRMNLP::ImageQuantizer do
  subject(:quantizer) { described_class.new(depth: depth) }

  let(:tool) { FakeMagick.new }
  let(:tmp_file) { instance_double(Tempfile, path: '/tmp/mono.png', close: nil) }

  class FakeMagick
    attr_reader :calls, :inputs

    def initialize
      @calls = []
      @inputs = []
    end

    def <<(arg) = @inputs << arg

    %i[colorspace dither posterize colors type remap depth define strip].each do |verb|
      define_method(verb) { |arg = nil| @calls << [verb, arg].compact }
    end

    def called?(verb, arg = nil)
      arg.nil? ? @calls.any? { |c| c[0] == verb } : @calls.include?([verb, arg])
    end
  end

  before do
    allow(Tempfile).to receive(:new).and_return(tmp_file)
    allow(FileUtils).to receive(:mv)
    allow(MiniMagick).to receive(:convert).and_yield(tool)
  end

  describe '#call' do
    let(:depth) { 4 }

    it 'streams source then destination paths to ImageMagick' do
      quantizer.call('/tmp/screenshot.png')
      expect(tool.inputs).to eq(['/tmp/screenshot.png', '/tmp/mono.png'])
    end

    it 'sets greyscale + Floyd-Steinberg dither' do
      quantizer.call('/tmp/screenshot.png')
      expect(tool.called?(:colorspace, 'Gray')).to be(true)
      expect(tool.called?(:dither, 'FloydSteinberg')).to be(true)
    end

    it 'moves the quantized tmp file over the original path' do
      quantizer.call('/tmp/screenshot.png')
      expect(FileUtils).to have_received(:mv).with('/tmp/mono.png', '/tmp/screenshot.png', force: true)
    end
  end

  describe 'depth handling' do
    context 'at depth 1' do
      let(:depth) { 1 }
      before { quantizer.call('/tmp/screenshot.png') }

      it 'remaps to a halftone pattern' do
        expect(tool.called?(:remap, 'pattern:gray50')).to be(true)
      end

      it 'forces Bilevel output' do
        expect(tool.called?(:type, 'Bilevel')).to be(true)
      end

      it 'posterizes to 2 levels' do
        expect(tool.called?(:posterize, 2)).to be(true)
      end
    end

    context 'at depth 4' do
      let(:depth) { 4 }
      before { quantizer.call('/tmp/screenshot.png') }

      it 'posterizes to 2**depth levels' do
        expect(tool.called?(:posterize, 16)).to be(true)
      end

      it 'does not apply the halftone remap' do
        expect(tool.called?(:remap)).to be(false)
      end

      it 'does not force Bilevel type' do
        expect(tool.called?(:type)).to be(false)
      end
    end

    context 'when depth exceeds 8' do
      let(:depth) { 99 }
      before { quantizer.call('/tmp/screenshot.png') }

      it 'clamps to 8' do
        expect(tool.called?(:depth, 8)).to be(true)
      end
    end

    context 'when depth is below 1' do
      let(:depth) { 0 }
      before { quantizer.call('/tmp/screenshot.png') }

      it 'clamps to 1' do
        expect(tool.called?(:depth, 1)).to be(true)
      end
    end
  end
end
