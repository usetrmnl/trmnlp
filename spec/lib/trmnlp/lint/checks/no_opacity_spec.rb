# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_opacity'

RSpec.describe TRMNLP::Lint::Checks::NoOpacity do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }

  describe '#issues' do
    context 'when markup sets an inline opacity value' do
      let(:markup) { '<div style="opacity: 0.5">faded</div>' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when markup uses Framework gray classes instead' do
      let(:markup) { '<div class="text--gray-5">muted</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
