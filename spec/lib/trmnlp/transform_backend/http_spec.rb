# frozen_string_literal: true

require 'spec_helper'
require 'faraday/adapter/test'
require 'trmnlp/transform_backend/http'

RSpec.describe TRMNLP::TransformBackend::Http do
  subject(:backend) { described_class.new(url: 'http://transform-runtime:8080', api_key: api_key) }

  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:faraday_conn) do
    Faraday.new do |f|
      f.headers['Content-Type'] = 'application/json'
      f.headers['Authorization'] = "Bearer #{api_key}" if api_key
      f.adapter :test, stubs
    end
  end
  let(:api_key) { nil }

  before { allow(backend).to receive(:connection).and_return(faraday_conn) }

  describe '#execute' do
    let(:payload) do
      { code: "def run(input):\n    return input", stdin: '{}', timeout_seconds: 5, language: 'python' }
    end

    it 'wraps user code with the FD-3 harness before sending (parity with the hosted service)' do
      received = nil
      stubs.post('/execute') do |env|
        received = JSON.parse(env.body)
        [200, {}, '{"stdout":"","stderr":"","output":"{}","exit_code":0,"duration_ms":12,"error":null}']
      end

      backend.execute(**payload)

      expect(received['language']).to eq('python')
      expect(received['stdin']).to eq('{}')
      expect(received['timeout']).to eq(5)
      expect(received['code']).to include("def run(input):\n    return input")
      expect(received['code']).to include("os.write(3, json.dumps(output).encode('utf-8'))")
    end

    it 'uses `timeout` not `timeout_seconds` in the body (daemon contract)' do
      received = nil
      stubs.post('/execute') do |env|
        received = JSON.parse(env.body)
        [200, {}, '{"output":"{}","exit_code":0}']
      end

      backend.execute(**payload)

      expect(received).to have_key('timeout')
      expect(received).not_to have_key('timeout_seconds')
    end

    context 'with an api_key' do
      let(:api_key) { 'secret-token' }

      it 'sends Authorization: Bearer header' do
        received_headers = nil
        stubs.post('/execute') do |env|
          received_headers = env.request_headers
          [200, {}, '{"output":"{}","exit_code":0}']
        end

        backend.execute(**payload)

        expect(received_headers['Authorization']).to eq('Bearer secret-token')
      end
    end

    it 'parses a success response into a Result' do
      stubs.post('/execute') do
        [200, {}, '{"stdout":"hi","stderr":"","output":"{\"ok\":true}","exit_code":0,"duration_ms":7,"error":null}']
      end

      result = backend.execute(**payload)

      expect(result).to have_attributes(stdout: 'hi', output: '{"ok":true}', exit_code: 0, error: nil)
      expect(result).to be_success
    end

    it 'falls back to stdout when output field is absent (older daemons)' do
      stubs.post('/execute') do
        [200, {}, '{"stdout":"{\"legacy\":true}","stderr":"","exit_code":0,"duration_ms":7,"error":null}']
      end

      result = backend.execute(**payload)

      expect(result.output).to eq('{"legacy":true}')
    end

    it 'returns a failure Result when the daemon responds non-200' do
      stubs.post('/execute') { [500, {}, 'kaboom'] }

      result = backend.execute(**payload)

      expect(result.error).to match(/daemon HTTP 500/)
      expect(result).not_to be_success
    end

    it 'returns a failure Result when the daemon is unreachable' do
      stubs.post('/execute') { raise Faraday::ConnectionFailed, 'cannot connect' }

      result = backend.execute(**payload)

      expect(result.error).to match(/transform daemon unreachable/)
    end

    it 'returns a failure Result when the daemon returns malformed JSON' do
      stubs.post('/execute') { [200, {}, 'not-json-at-all'] }

      result = backend.execute(**payload)

      expect(result.error).to match(/non-JSON/)
    end

    it 'returns a failure Result for unknown languages (parity with the Subprocess backend)' do
      result = backend.execute(code: 'x', language: 'cobol', stdin: '')

      expect(result).not_to be_success
      expect(result.error).to match(/unsupported serverless_language: cobol/)
    end
  end
end
