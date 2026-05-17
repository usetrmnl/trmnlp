# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/transform_client'

RSpec.describe TRMNLP::TransformClient do
  describe '.from_config' do
    let(:project_config) { double('project_config') }

    context 'when transform_runtime is nil' do
      before { allow(project_config).to receive_messages(transform_runtime: nil) }

      it 'returns nil (serverless disabled)' do
        expect(described_class.from_config(project_config)).to be_nil
      end
    end

    context 'when transform_runtime is "disabled"' do
      before { allow(project_config).to receive_messages(transform_runtime: 'disabled') }

      it 'returns nil' do
        expect(described_class.from_config(project_config)).to be_nil
      end
    end

    context 'when transform_runtime is enabled and no daemon url is set' do
      before do
        allow(project_config).to receive_messages(
          transform_runtime: 'enabled',
          serverless_daemon_url: nil
        )
      end

      it 'builds a client backed by the local Subprocess backend' do
        client = described_class.from_config(project_config)
        expect(client.backend).to be_a(TRMNLP::TransformBackend::Subprocess)
      end
    end

    context 'when serverless_daemon_url is set' do
      before do
        allow(project_config).to receive_messages(
          transform_runtime: 'enabled',
          serverless_daemon_url: 'http://daemon:8080',
          serverless_daemon_api_key: 'tok-abc'
        )
      end

      it 'builds a client backed by the Http backend pointing at the configured url' do
        client = described_class.from_config(project_config)
        expect(client.backend).to be_a(TRMNLP::TransformBackend::Http)
      end

      it 'passes the api_key through to the Http backend' do
        expect(TRMNLP::TransformBackend::Http).to receive(:new).with(url: 'http://daemon:8080',
                                                                     api_key: 'tok-abc').and_call_original
        described_class.from_config(project_config)
      end
    end
  end

  describe '#execute' do
    subject(:client) { described_class.new(backend: backend) }

    let(:backend) { instance_double(TRMNLP::TransformBackend::Subprocess) }
    let(:result) do
      TRMNLP::TransformClient::Result.new(
        stdout: '', stderr: '', output: '{"ok":true}',
        exit_code: 0, duration_ms: 3, error: nil
      )
    end

    before { allow(backend).to receive(:execute).and_return(result) }

    it 'delegates to the backend with the provided arguments' do
      client.execute(code: 'noop', language: 'ruby', stdin: '{}', timeout_seconds: 5)

      expect(backend).to have_received(:execute).with(
        code: 'noop', language: 'ruby', stdin: '{}', timeout_seconds: 5
      )
    end

    it 'returns the backend Result unchanged' do
      expect(client.execute(code: 'noop', language: 'ruby', stdin: '{}')).to be(result)
    end
  end

  describe 'Result' do
    it 'reports success when error is nil and exit_code is 0' do
      result = described_class::Result.new(stdout: '', stderr: '', output: '', exit_code: 0, duration_ms: 0, error: nil)
      expect(result).to be_success
    end

    it 'is not successful when error is present' do
      result = described_class::Result.new(stdout: '', stderr: '', output: '', exit_code: 0, duration_ms: 0,
                                           error: 'oops')
      expect(result).not_to be_success
    end

    it 'is not successful when exit_code is non-zero' do
      result = described_class::Result.new(stdout: '', stderr: '', output: '', exit_code: 1, duration_ms: 0, error: nil)
      expect(result).not_to be_success
    end
  end
end
