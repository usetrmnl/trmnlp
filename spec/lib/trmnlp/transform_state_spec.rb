# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::TransformState do
  subject(:transform_state) { described_class.new(paths:, reporter:) }

  let(:paths) { TRMNLP::Paths.new(File.join(__dir__, '../../fixtures')) }
  let(:reporter) { instance_spy(TRMNLP::Reporter, yellow: 'warned') }
  let(:cache_dir) { Pathname.new(Dir.mktmpdir) }

  before { allow(paths).to receive(:cache_dir).and_return(cache_dir) }
  after { FileUtils.remove_entry(cache_dir) }

  describe '#read' do
    it 'answers an empty state before any transform kept one' do
      expect(transform_state.read).to eq({})
    end

    it 'answers an empty state when the stored file is not JSON' do
      paths.transform_state.dirname.mkpath
      paths.transform_state.write('nope')

      expect(transform_state.read).to eq({})
    end
  end

  describe '#extract!' do
    it 'keeps the returned trmnl_state for the next run' do
      transform_state.extract!('trmnl_state' => { 'etag' => 'abc' })

      expect(transform_state.read).to eq('etag' => 'abc')
    end

    it 'removes trmnl_state from what renders' do
      output = { 'items' => [1], 'trmnl_state' => { 'etag' => 'abc' } }
      transform_state.extract!(output)

      expect(output).to eq('items' => [1])
    end

    it 'leaves the stored state alone when the output has no trmnl_state' do
      transform_state.extract!('trmnl_state' => { 'etag' => 'abc' })
      transform_state.extract!('items' => [1])

      expect(transform_state.read).to eq('etag' => 'abc')
    end

    it 'ignores a trmnl_state that is not an object' do
      transform_state.extract!('trmnl_state' => 'abc')

      expect(transform_state.read).to eq({})
    end

    it 'reports a trmnl_state that is not an object' do
      transform_state.extract!('trmnl_state' => 'abc')

      expect(reporter).to have_received(:yellow).with('Ignored trmnl_state: expected an object, got String')
    end

    it 'ignores a trmnl_state over 8 kB' do
      transform_state.extract!('trmnl_state' => { 'blob' => 'x' * 8200 })

      expect(reporter).to have_received(:yellow).with('Ignored trmnl_state: 8211 bytes exceeds the 8192 byte limit')
    end
  end
end
