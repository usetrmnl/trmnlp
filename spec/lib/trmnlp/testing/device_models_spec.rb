# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/testing/device_models'

RSpec.describe TRMNLP::Testing::DeviceModels do
  let(:models) do
    [{ 'name' => 'og_plus', 'width' => 800, 'height' => 480, 'bit_depth' => 2, 'palette_ids' => %w[bw gray-4],
       'image_size_limit' => 90_000, 'css' => { 'classes' => { 'device' => 'screen--ogv2', 'size' => 'screen--md' } } }]
  end
  let(:palettes) do
    [{ 'id' => 'bw', 'grays' => 2, 'framework_class' => 'screen--1bit' },
     { 'id' => 'gray-4', 'grays' => 4, 'framework_class' => 'screen--2bit' }]
  end

  before { allow(described_class).to receive_messages(models:, palettes:) }

  describe '.find' do
    it "gives a model the picker's screen classes, with the palette matching its bit depth" do
      expect(described_class.find('og_plus').screen_classes).to eq('screen screen--2bit screen--ogv2 screen--md')
    end

    it 'swaps the size and marks the classes in portrait' do
      expect(described_class.find('og_plus', orientation: :portrait))
        .to have_attributes(width: 480, height: 800, screen_classes: end_with('screen--portrait'))
    end

    it "draws in another of the model's palettes at that palette's depth" do
      expect(described_class.find('og_plus', palette: 'bw'))
        .to have_attributes(bit_depth: 1, screen_classes: start_with('screen screen--1bit'))
    end

    it "names the model's palettes for one it does not have" do
      expect { described_class.find('og_plus', palette: 'gray-16') }.to raise_error(TRMNLP::TestingError, /bw, gray-4/)
    end

    it 'takes a Hash for a custom screen' do
      expect(described_class.find({ width: 400, height: 300, bit_depth: 4 }).render_params)
        .to eq(width: 400, height: 300, model: 'custom', bit_depth: 4)
    end

    it 'names the known models for an unknown one' do
      expect { described_class.find('nope') }.to raise_error(TRMNLP::TestingError, /known: og_plus/)
    end
  end

  describe '.fetch' do
    it 'answers the data of a TRMNL API listing' do
      stub_request(:get, 'https://trmnl.com/api/palettes').to_return(body: '{"data":[{"id":"bw"}]}')

      expect(described_class.fetch('palettes')).to eq([{ 'id' => 'bw' }])
    end

    it 'says how to test offline when the API is unreachable' do
      stub_request(:get, 'https://trmnl.com/api/models').to_timeout

      expect { described_class.fetch('models') }.to raise_error(TRMNLP::TestingError, /device Hash/)
    end
  end
end
