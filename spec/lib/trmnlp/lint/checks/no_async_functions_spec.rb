# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_async_functions'

RSpec.describe TRMNLP::Lint::Checks::NoAsyncFunctions do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }

  describe '#issues' do
    context 'when the markup defines an async function' do
      let(:markup) { '<script>async function load() {}</script>' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the markup uses only synchronous functions' do
      let(:markup) { '<script>function load() {}</script>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
