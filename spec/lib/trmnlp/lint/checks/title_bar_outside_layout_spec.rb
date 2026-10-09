# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/title_bar_outside_layout'

RSpec.describe TRMNLP::Lint::Checks::TitleBarOutsideLayout do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, html_fragments: { 'src/full.liquid' => Nokogiri::HTML.fragment(markup) }) }

  describe '#issues' do
    context 'when the title bar is inside the layout' do
      let(:markup) { '<div class="layout"><div class="columns"><div class="title_bar">Hi</div></div></div>' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the title bar follows the layout' do
      let(:markup) { '<div class="layout layout--col">Body</div><div class="title_bar">Hi</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the markup has no layout' do
      let(:markup) { '<div class="title_bar">Hi</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
