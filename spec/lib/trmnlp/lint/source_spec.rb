# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'

RSpec.describe TRMNLP::Lint::Source do
  subject(:source) { described_class.new(config:, paths: nil) }

  let(:config) { instance_double(TRMNLP::Config, plugin: plugin_config) }
  let(:plugin_config) { instance_double(TRMNLP::Config::Plugin, settings:) }

  describe '#plugin_description' do
    context 'when settings.yml sets a description' do
      let(:settings) { { 'description' => 'Top stories from HN' } }

      it 'answers the value' do
        expect(source.plugin_description).to eq('Top stories from HN')
      end
    end

    context 'when settings.yml omits the key' do
      let(:settings) { { 'name' => 'Hacker News' } }

      it 'answers an empty string' do
        expect(source.plugin_description).to eq('')
      end
    end

    context 'when the key is present with no value' do
      let(:settings) { { 'description' => nil } }

      it 'answers an empty string' do
        expect(source.plugin_description).to eq('')
      end
    end
  end
end
