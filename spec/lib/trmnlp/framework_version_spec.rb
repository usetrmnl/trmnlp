# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/framework_version'

RSpec.describe TRMNLP::FrameworkVersion do
  subject(:framework) { described_class.new('1.0.0') }

  let(:bundled) { YAML.load_file(described_class::DATA_PATH) }

  describe '.config' do
    let(:published) { { 'latest' => '99.1.0', 'versions' => [{ 'number' => '99.1.0' }] } }

    around do |example|
      memoized = described_class.instance_variable_get(:@config)
      described_class.instance_variable_set(:@config, nil)
      example.run
      described_class.instance_variable_set(:@config, memoized)
    end

    it 'answers the published manifest' do
      stub_request(:get, described_class::MANIFEST_URL).to_return(body: published.to_yaml)

      expect(described_class.config).to eq(published)
    end

    it 'answers a manifest with unquoted release dates' do
      body = "latest: 99.1.0\nversions:\n- number: 99.1.0\n  released_at: 2026-08-03\n"
      stub_request(:get, described_class::MANIFEST_URL).to_return(body:)

      expect(described_class.version_numbers).to eq(['99.1.0'])
    end

    it 'answers the bundled copy when the manifest is unreachable' do
      stub_request(:get, described_class::MANIFEST_URL).to_timeout

      expect(described_class.config).to eq(bundled)
    end

    it 'answers the bundled copy when the request fails' do
      stub_request(:get, described_class::MANIFEST_URL).to_return(status: 500)

      expect(described_class.config).to eq(bundled)
    end

    it 'answers the bundled copy when the response is not a manifest' do
      stub_request(:get, described_class::MANIFEST_URL).to_return(body: '<html>Not Found</html>')

      expect(described_class.config).to eq(bundled)
    end

    it 'reads the manifest once' do
      described_class.config
      described_class.config

      expect(WebMock).to have_requested(:get, described_class::MANIFEST_URL).once
    end
  end

  describe '.version_numbers' do
    it 'answers every number in the manifest' do
      numbers = bundled.fetch('versions').map { |version| version['number'] }

      expect(described_class.version_numbers).to eq(numbers)
    end
  end

  describe '.latest' do
    it 'answers the manifest latest' do
      expect(described_class.latest.number).to eq(bundled.fetch('latest'))
    end

    it 'is pinned' do
      expect(described_class.latest.pinned?).to be(true)
    end
  end

  describe '.options' do
    it 'answers latest as the first option' do
      label = "Always track latest (currently v#{bundled.fetch('latest')})"

      expect(described_class.options.first).to eq(label => 'latest')
    end

    it 'orders the pinnable versions newest-first by semantic version' do
      pinned = described_class.options.drop(1).map { |option| option.values.first }

      expect(pinned).to eq(pinned.sort_by { |number| Gem::Version.new(number) }.reverse)
    end
  end

  describe '#initialize' do
    it 'answers the latest number when given nil' do
      expect(described_class.new(nil).number).to eq(bundled.fetch('latest'))
    end

    it 'raises an argument error when given an unknown version' do
      expectation = proc { described_class.new('99.99.99') }

      expect(&expectation).to raise_error(ArgumentError, /unknown framework version/)
    end
  end

  describe '#pinned?' do
    it 'answers true when given a version' do
      expect(framework.pinned?).to be(true)
    end

    it 'answers false when given latest' do
      expect(described_class.new('latest').pinned?).to be(false)
    end
  end

  describe '#css_url' do
    it 'answers the version-specific path' do
      expect(framework.css_url).to eq('https://trmnl.com/css/1.0.0/plugins.css')
    end

    context 'when tracking latest' do
      subject(:framework) { described_class.new('latest') }

      # NOTE: "latest" resolves to a concrete version rather than the
      # auto-upgrading /latest/ CDN path, matching the hosted service —
      # otherwise a local preview silently drifts when a new release ships.
      it 'answers the concrete current version' do
        expect(framework.css_url).to eq("https://trmnl.com/css/#{bundled.fetch('latest')}/plugins.css")
      end
    end

    context 'with a custom asset host' do
      subject(:framework) { described_class.new('1.0.0', asset_host: 'https://cdn.example.com') }

      it 'answers the override host' do
        expect(framework.css_url).to eq('https://cdn.example.com/css/1.0.0/plugins.css')
      end
    end
  end

  describe '#js_url' do
    it 'answers the version-specific path' do
      expect(framework.js_url).to eq('https://trmnl.com/js/1.0.0/plugins.js')
    end

    context 'with a custom asset host' do
      subject(:framework) { described_class.new('1.0.0', asset_host: 'https://cdn.example.com') }

      it 'answers the override host' do
        expect(framework.js_url).to eq('https://cdn.example.com/js/1.0.0/plugins.js')
      end
    end
  end

  describe '#==' do
    it 'answers true for the same number' do
      expect(framework == described_class.new('1.0.0')).to be(true)
    end

    it 'answers false for a different number' do
      expect(framework == described_class.new('2.0.0')).to be(false)
    end

    it 'answers false for a different type' do
      expect(framework == '1.0.0').to be(false)
    end
  end

  describe '#<=>' do
    it 'orders by semantic version' do
      expect(framework).to be < described_class.new('2.0.0')
    end

    it 'answers nil for a different type' do
      expect(framework <=> '1.0.0').to be(nil)
    end
  end

  describe '#as_json' do
    it 'answers the number' do
      expect(framework.as_json).to eq('1.0.0')
    end
  end

  describe '#to_s' do
    it 'answers the number' do
      expect(framework.to_s).to eq('1.0.0')
    end
  end
end
