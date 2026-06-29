# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'trmnlp/transform_backend/subprocess'

RSpec.describe TRMNLP::TransformBackend::Subprocess do
  subject(:backend) { described_class.new }

  describe '#execute' do
    it 'runs a real ruby transform and returns the harness output' do
      result = backend.execute(
        code: "def run(input); { 'echoed' => input['greeting'] }; end",
        language: 'ruby',
        stdin: JSON.generate('greeting' => 'hello')
      )

      expect(result).to be_success
      expect(JSON.parse(result.output)).to eq('echoed' => 'hello')
    end

    it 'falls back to result variable when run is not defined (parity with the hosted wrapper dispatch)' do
      result = backend.execute(
        code: "result = { 'fallback' => true }",
        language: 'ruby',
        stdin: '{}'
      )

      expect(JSON.parse(result.output)).to eq('fallback' => true)
    end

    it 'recognizes function transform(input) for node (parity with the hosted node wrapper)' do
      result = backend.execute(
        code: 'function transform(input) { return { upper: input.text.toUpperCase() }; }',
        language: 'node',
        stdin: JSON.generate('text' => 'hello')
      )

      expect(result).to be_success
      expect(JSON.parse(result.output)).to eq('upper' => 'HELLO')
    end

    it 'runs a real python transform and returns the harness output' do
      result = backend.execute(
        code: "def run(input):\n    return { 'echoed': input['greeting'] }",
        language: 'python',
        stdin: JSON.generate('greeting' => 'hello')
      )

      expect(result).to be_success
      expect(JSON.parse(result.output)).to eq('echoed' => 'hello')
    end

    it 'runs a real php transform and returns the harness output' do
      result = backend.execute(
        code: "<?php\nfunction run($input) { return ['echoed' => $input['greeting']]; }",
        language: 'php',
        stdin: JSON.generate('greeting' => 'hello')
      )

      expect(result).to be_success
      expect(JSON.parse(result.output)).to eq('echoed' => 'hello')
    end

    it 'returns a failure Result for unsupported languages' do
      result = backend.execute(code: 'noop', language: 'cobol', stdin: '')

      expect(result).not_to be_success
      expect(result.error).to match(/unsupported language: cobol/)
    end

    it 'returns a failure Result when the user transform raises' do
      result = backend.execute(
        code: "def run(input); raise 'boom'; end",
        language: 'ruby',
        stdin: '{}'
      )

      expect(result).not_to be_success
      expect(result.stderr).to include('boom')
    end

    it 'enforces the timeout' do
      result = backend.execute(
        code: 'def run(input); sleep 5; input; end',
        language: 'ruby',
        stdin: '{}',
        timeout_seconds: 1
      )

      expect(result).not_to be_success
      expect(result.error).to match(/timeout/)
    end

    it 'reports the interpreter command as failure when it is not on PATH' do
      stub_const("#{described_class}::INTERPRETERS", {
                   'ghost' => { cmds: %w[this-binary-does-not-exist], ext: 'rb' }
                 })

      result = backend.execute(code: 'noop', language: 'ghost', stdin: '')

      expect(result).not_to be_success
      expect(result.error).to match(/interpreter not available/)
    end
  end
end
