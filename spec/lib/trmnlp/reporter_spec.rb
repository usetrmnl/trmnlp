# frozen_string_literal: true

require 'spec_helper'
require 'stringio'
require 'trmnlp/reporter'

RSpec.describe TRMNLP::Reporter do
  let(:stream) { StringIO.new }

  describe '#info' do
    context 'when not quiet' do
      subject(:reporter) { described_class.new(stream:) }

      it 'writes the message to the stream' do
        reporter.info('hello')
        expect(stream.string).to eq("hello\n")
      end

      it 'records every message' do
        reporter.info('one')
        reporter.info('two')
        expect(reporter.messages).to eq(%w[one two])
      end
    end

    context 'when quiet' do
      subject(:reporter) { described_class.new(quiet: true, stream:) }

      it 'records the message but does not write to the stream' do
        reporter.info('ignored')

        expect(reporter.messages).to eq(['ignored'])
        expect(stream.string).to be_empty
      end
    end
  end

  describe '#green' do
    context 'when the stream is a terminal' do
      subject(:reporter) { described_class.new(stream:) }

      before { allow(stream).to receive(:tty?).and_return(true) }

      it 'wraps the text in the green ANSI code' do
        expect(reporter.green('ok')).to eq("\e[32mok\e[0m")
      end
    end

    context 'when the stream is not a terminal' do
      subject(:reporter) { described_class.new(stream:) }

      it 'returns plain text so ANSI never leaks into redirected output' do
        expect(reporter.green('ok')).to eq('ok')
      end
    end
  end

  describe '#yellow' do
    subject(:reporter) { described_class.new(stream:) }

    before { allow(stream).to receive(:tty?).and_return(true) }

    it 'wraps the text in the yellow ANSI code' do
      expect(reporter.yellow('hmm')).to eq("\e[33mhmm\e[0m")
    end
  end

  describe '#red' do
    subject(:reporter) { described_class.new(stream:) }

    before { allow(stream).to receive(:tty?).and_return(true) }

    it 'wraps the text in the red ANSI code' do
      expect(reporter.red('no')).to eq("\e[31mno\e[0m")
    end
  end
end
