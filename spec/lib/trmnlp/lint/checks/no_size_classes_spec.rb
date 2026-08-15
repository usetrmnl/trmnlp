# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_size_classes'

RSpec.describe TRMNLP::Lint::Checks::NoSizeClasses do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }

  describe '#issues' do
    context 'when the markup re-applies a view size class' do
      let(:markup) { '<div class="view--full">content</div>' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the markup uses its own classes' do
      let(:markup) { '<div class="headline">content</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
