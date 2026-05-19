# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/framework_version'

RSpec.describe TRMNLP::FrameworkVersion do
  describe '.latest' do
    subject(:latest) { described_class.latest }

    it 'is pinned' do
      expect(latest).to be_pinned
    end

    it 'has a version number' do
      expect(latest.number).to match(/\A\d+\.\d+\.\d+\z/)
    end
  end

  describe '#css_url and #js_url' do
    context 'when version is "latest"' do
      subject(:framework) { described_class.new('latest') }

      # NOTE: "latest" resolves to a concrete version rather than the
      # auto-upgrading /latest/ CDN path, matching the hosted service —
      # otherwise a local preview silently drifts when a new release ships.
      it 'serves from the concrete current version' do
        number = described_class.latest.number

        expect(framework.css_url).to eq("https://trmnl.com/css/#{number}/plugins.css")
        expect(framework.js_url).to eq("https://trmnl.com/js/#{number}/plugins.js")
      end
    end

    context 'when a specific version is pinned' do
      subject(:framework) { described_class.new('1.0.0') }

      it 'serves from the version-specific path' do
        expect(framework.css_url).to eq('https://trmnl.com/css/1.0.0/plugins.css')
        expect(framework.js_url).to eq('https://trmnl.com/js/1.0.0/plugins.js')
      end
    end

    context 'with a custom asset host' do
      subject(:framework) { described_class.new('1.0.0', asset_host: 'https://cdn.example.com') }

      it 'honours the override' do
        expect(framework.css_url).to eq('https://cdn.example.com/css/1.0.0/plugins.css')
      end
    end
  end

  describe '#initialize' do
    it 'accepts nil as latest' do
      expect(described_class.new(nil)).not_to be_pinned
    end

    it 'raises on an unknown version' do
      expect { described_class.new('99.99.99') }
        .to raise_error(ArgumentError, /unknown framework version/)
    end
  end

  describe '#<=>' do
    it 'orders by semantic version' do
      v1 = described_class.new('1.0.0')
      v2 = described_class.new('2.0.0')

      expect(v1).to be < v2
    end
  end

  describe '.options' do
    it 'orders the pinnable versions newest-first by semantic version' do
      pinned = described_class.options.drop(1).map { |option| option.values.first }

      expect(pinned).to eq(pinned.sort_by { |number| Gem::Version.new(number) }.reverse)
    end
  end
end
