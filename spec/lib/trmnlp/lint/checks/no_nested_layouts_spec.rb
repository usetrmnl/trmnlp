# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_nested_layouts'

RSpec.describe TRMNLP::Lint::Checks::NoNestedLayouts do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, html_fragments: { 'src/full.liquid' => Nokogiri::HTML.fragment(markup) }) }

  describe '#issues' do
    context 'when a layout is inside another layout' do
      let(:markup) { '<div class="layout"><div class="column"><div class="layout layout--row">x</div></div></div>' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when layouts are siblings and modifiers sit inside' do
      let(:markup) { '<div class="layout"><div class="layout--row">x</div></div><div class="layout">y</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the markup has no layout' do
      let(:markup) { '<div class="columns">x</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
