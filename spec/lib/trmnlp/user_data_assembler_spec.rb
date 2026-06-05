# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/transform_client'

RSpec.describe TRMNLP::UserDataAssembler do
  subject(:assembler) { described_class.new(config:, paths:, transform_pipeline:) }

  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:transform_pipeline) { TRMNLP::TransformPipeline.new(config:, paths:) }

  describe '#call' do
    before do
      allow(config.plugin).to receive(:static?).and_return(false)
      allow(paths.user_data).to receive(:exist?).and_return(false)
    end

    context 'without device overrides' do
      it 'uses the default device dimensions' do
        expect(assembler.call.dig('trmnl', 'device', 'width')).to eq(800)
        expect(assembler.call.dig('trmnl', 'device', 'height')).to eq(480)
      end
    end

    context 'with device overrides from the picker' do
      it 'uses the supplied dimensions (issue #94)' do
        data = assembler.call(device: { 'width' => 400, 'height' => 240 })

        expect(data.dig('trmnl', 'device', 'width')).to eq(400)
        expect(data.dig('trmnl', 'device', 'height')).to eq(240)
      end
    end

    context 'with trmnl namespace overrides in .trmnlp variables' do
      before do
        allow(config.project).to receive(:user_data_overrides).and_return(
          'trmnl' => {
            'user' => {
              'time_zone' => 'Central Time (US & Canada)',
              'time_zone_iana' => 'America/Chicago',
              'utc_offset' => -18_000
            }
          }
        )
      end

      it 'applies the overrides to the trmnl namespace (regression: overrides were dropped after transform)' do
        data = assembler.call

        expect(data.dig('trmnl', 'user', 'time_zone')).to eq('Central Time (US & Canada)')
        expect(data.dig('trmnl', 'user', 'time_zone_iana')).to eq('America/Chicago')
        expect(data.dig('trmnl', 'user', 'utc_offset')).to eq(-18_000)
      end

      it 'does not clobber other trmnl namespace keys' do
        data = assembler.call

        expect(data.dig('trmnl', 'device', 'width')).to eq(800)
        expect(data.dig('trmnl', 'user', 'locale')).to eq('en')
      end
    end
  end

  describe '#device_from_params' do
    it 'extracts width and height from string params' do
      expect(assembler.device_from_params(width: '400', height: '240'))
        .to eq('width' => 400, 'height' => 240)
    end

    it 'returns an empty hash when neither param is present' do
      expect(assembler.device_from_params({})).to eq({})
    end
  end

  describe '#call (through the transform pipeline)' do
    let(:transform_client) { instance_double(TRMNLP::TransformClient) }
    let(:transform_path) { Pathname.new('/tmp/fake-transform.py') }

    before do
      allow(config.plugin).to receive(:static?).and_return(true)
      allow(config.plugin).to receive_messages(
        static_data: { 'items' => [1, 2, 3] },
        serverless_language: nil
      )
      allow(paths).to receive(:transform_file).and_return([transform_path, 'python'])
      allow(transform_path).to receive(:read).and_return('# transform code')
      allow(transform_path).to receive(:extname).and_return('.py')
      allow(transform_path).to receive(:exist?).and_return(true)
      allow(TRMNLP::TransformClient).to receive(:from_config).and_return(transform_client)
    end

    context 'when the plugin uses static strategy and a transform is configured' do
      before do
        allow(transform_client).to receive(:execute).and_return(
          TRMNLP::TransformClient::Result.new(
            stdout: '', stderr: '', output: '{"items":[2,4,6]}', exit_code: 0, duration_ms: 5, error: nil
          )
        )
      end

      it 'runs the transform against static_data (matches the hosted pipeline)' do
        result = assembler.call
        expect(result['items']).to eq([2, 4, 6])
      end

      it 'forwards the assembled data (including trmnl namespace) to the transform' do
        assembler.call

        expect(transform_client).to have_received(:execute) do |kwargs|
          stdin = JSON.parse(kwargs[:stdin])
          expect(stdin['items']).to eq([1, 2, 3])
          expect(stdin['trmnl']['device']['width']).to eq(800)
        end
      end

      it 'preserves the trmnl namespace even when the transform omits it' do
        result = assembler.call
        expect(result.dig('trmnl', 'device', 'width')).to eq(800)
      end
    end

    context 'when the transform fails' do
      before do
        allow(transform_client).to receive(:execute).and_return(
          TRMNLP::TransformClient::Result.new(
            stdout: '', stderr: 'KaBoom', output: '', exit_code: 1, duration_ms: 5, error: nil
          )
        )
      end

      it 'falls back to the untransformed data and records the error on the pipeline' do
        result = assembler.call
        expect(result['items']).to eq([1, 2, 3])
        expect(transform_pipeline.error).to include('KaBoom')
      end
    end
  end
end
