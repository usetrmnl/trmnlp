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
end
