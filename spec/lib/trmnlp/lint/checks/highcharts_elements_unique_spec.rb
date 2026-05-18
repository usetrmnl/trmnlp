# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/highcharts_elements_unique'

RSpec.describe TRMNLP::Lint::Checks::HighchartsElementsUnique do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }

  describe '#issues' do
    context 'when Highcharts is used without the append_random filter' do
      let(:markup) { '<div id="highcharts">chart</div>' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when Highcharts elements use the append_random filter' do
      let(:markup) { '<div id="{{ "highcharts" | append_random }}">chart</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
