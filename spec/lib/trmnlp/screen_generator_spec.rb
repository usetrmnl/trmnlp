# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/screen_generator'

RSpec.describe TRMNLP::ScreenGenerator do
  subject(:generator) { described_class.new(html, screenshot:, **opts) }

  let(:tempfile) { instance_double(Tempfile, path: '/tmp/shot.png') }
  let(:screenshot) { instance_double(TRMNLP::Screenshot, call: tempfile) }
  let(:quantizer) { instance_double(TRMNLP::ImageQuantizer, call: nil) }
  let(:html) { '<div class="screen screen--2bit">hi</div>' }
  let(:opts) { {} }

  before { allow(TRMNLP::ImageQuantizer).to receive(:new).and_return(quantizer) }

  describe '#process' do
    it 'asks the screenshot to render the input HTML' do
      generator.process
      expect(screenshot).to have_received(:call).with(html: html, width: 800, height: 480)
    end

    it 'asks the quantizer to mutate the screenshot in place' do
      generator.process
      expect(quantizer).to have_received(:call).with(tempfile.path)
    end

    it 'returns the screenshot tempfile' do
      expect(generator.process).to be(tempfile)
    end
  end

  describe 'dimension defaults' do
    it 'defaults to 800x480 when no opts are provided' do
      generator.process
      expect(screenshot).to have_received(:call).with(hash_including(width: 800, height: 480))
    end

    context 'when width and height are provided' do
      let(:opts) { { width: 400, height: 240 } }

      it 'passes the requested dimensions through' do
        generator.process
        expect(screenshot).to have_received(:call).with(hash_including(width: 400, height: 240))
      end
    end
  end

  describe 'color depth inference' do
    it 'reads screen--Nbit from the HTML when no depth is supplied' do
      generator.process
      expect(TRMNLP::ImageQuantizer).to have_received(:new).with(depth: 2)
    end

    context 'when an explicit color_depth is supplied' do
      let(:opts) { { color_depth: 4 } }

      it 'overrides the inferred depth' do
        generator.process
        expect(TRMNLP::ImageQuantizer).to have_received(:new).with(depth: 4)
      end
    end

    context 'when neither the HTML nor opts specify a depth' do
      let(:html) { '<p>plain</p>' }

      it 'falls back to 1-bit' do
        generator.process
        expect(TRMNLP::ImageQuantizer).to have_received(:new).with(depth: 1)
      end
    end
  end
end
