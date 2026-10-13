# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_style_restyling_framework'

RSpec.describe TRMNLP::Lint::Checks::NoStyleRestylingFramework do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, markup_files: { 'src/shared.liquid' => markup }) }
  let(:messages) { check.issues.map { it[:message] } }

  describe '#issues' do
    context 'when a <style> block sets a font size in pixels' do
      let(:markup) { '<style>.wc-title{font-size:22px;font-weight:700}</style>' }

      it 'points at the element sizes' do
        expect(messages).to contain_exactly(include('font-size', 'element sizes'))
      end
    end

    context 'when a <style> block clamps lines by hand' do
      let(:markup) { '<style>.ww-clamp2 { display: -webkit-box; -webkit-line-clamp: 2; }</style>' }

      it 'points at data-clamp' do
        expect(messages).to contain_exactly(include('-webkit-line-clamp', 'data-clamp'))
      end
    end

    context 'when a <style> block reflows on orientation' do
      let(:markup) { '<style>@media (orientation: portrait) { .row { flex-direction: column } }</style>' }

      it 'points at the portrait: prefix' do
        expect(messages).to contain_exactly(include('@media (orientation', 'portrait:'))
      end
    end

    context 'with each kind once' do
      let(:markup) { '<style>.a{font-size:12px}.b{font-size:14pt}</style><style>.c{-webkit-line-clamp:3}</style>' }

      it 'reports one finding per kind' do
        expect(check.issues.size).to eq(2)
      end
    end

    {
      'a font size from a framework token' => '<style>.nk-t1 { font-size: var(--label-font-size); }</style>',
      'a font size that scales with the screen' => '<style>.sc .number { font-size: 3.6cqh }</style>',
      'a font size on SVG text' => '<style>.dial svg text { font-size: 12px }</style>',
      'a font size on a chart' => '<style>.highcharts-axis-labels { font-size: 14px }</style>',
      'a font size in an inline style' => '<span style="font-size:16px">x</span>',
      'art-only CSS' => '<style>.bin { clip-path: polygon(0 0, 100% 0, 50% 100%); }</style>'
    }.each do |what, markup|
      context "with #{what}" do
        let(:markup) { markup }

        it 'passes' do
          expect(check.issues).to be_empty
        end
      end
    end
  end
end
