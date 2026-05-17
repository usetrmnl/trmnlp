# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/transform_pipeline'

RSpec.describe TRMNLP::TransformPipeline do
  subject(:pipeline) { described_class.new(config:, paths:, reporter:) }

  let(:tmp_root) { Dir.mktmpdir('trmnlp-tx-') }
  let(:paths) { TRMNLP::Paths.new(tmp_root) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:reporter) { TRMNLP::Reporter.new(quiet: true) }

  before { File.write(File.join(tmp_root, '.trmnlp.yml'), '{}') }
  after { FileUtils.rm_rf(tmp_root) }

  describe '#call' do
    context 'when no transform file is present' do
      it 'returns the data untouched' do
        expect(pipeline.call('count' => 1)).to eq('count' => 1)
      end
    end

    context 'when a transform file is present' do
      let(:client) { instance_double(TRMNLP::TransformClient) }
      let(:success_result) do
        TRMNLP::TransformClient::Result.new(stdout: '', stderr: '', output: '{"doubled":4}',
                                            exit_code: 0, duration_ms: 0, error: nil)
      end
      let(:failure_result) do
        TRMNLP::TransformClient::Result.new(stdout: '', stderr: 'boom', output: '',
                                            exit_code: 1, duration_ms: 0, error: nil)
      end
      let(:non_json_result) do
        TRMNLP::TransformClient::Result.new(stdout: '', stderr: '', output: 'not json',
                                            exit_code: 0, duration_ms: 0, error: nil)
      end

      before do
        FileUtils.mkdir_p(File.join(tmp_root, 'src'))
        File.write(File.join(tmp_root, 'src', 'transform.rb'), 'def run(input) = input')
        allow(TRMNLP::TransformClient).to receive(:from_config).and_return(client)
      end

      it 'returns the transform output on success' do
        allow(client).to receive(:execute).and_return(success_result)

        expect(pipeline.call('n' => 2)).to eq('doubled' => 4)
      end

      it 'falls back to the input data on failure' do
        allow(client).to receive(:execute).and_return(failure_result)

        expect(pipeline.call('n' => 2)).to eq('n' => 2)
      end

      it 'exposes the failure through #error' do
        allow(client).to receive(:execute).and_return(failure_result)
        pipeline.call('n' => 2)

        expect(pipeline.error).to match(/transform exited 1/)
      end

      it 'records non-JSON transform output as an error' do
        allow(client).to receive(:execute).and_return(non_json_result)
        pipeline.call('n' => 2)

        expect(pipeline.error).to match(/non-JSON/)
      end

      it 'surfaces the failure through the reporter' do
        allow(client).to receive(:execute).and_return(failure_result)
        pipeline.call('n' => 2)

        expect(reporter.messages).to include(a_string_matching(/transform failed/))
      end
    end
  end
end
