# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::Context do
  describe '#validate!' do
    context 'when the directory is not a plugin' do
      subject(:context) { described_class.new('/tmp') }

      it 'raises NotAPlugin' do
        expect { context.validate! }.to raise_error(TRMNLP::NotAPlugin)
      end
    end

    context 'when the directory is a plugin' do
      subject(:context) { described_class.new(File.join(__dir__, '../../fixtures')) }

      it 'returns without raising' do
        expect { context.validate! }.not_to raise_error
      end
    end
  end
end
