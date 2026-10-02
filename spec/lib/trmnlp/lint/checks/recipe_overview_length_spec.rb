# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/recipe_overview_length'

RSpec.describe TRMNLP::Lint::Checks::RecipeOverviewLength do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, recipe_overview: overview) }

  describe '#issues' do
    context 'when the overview has fewer than 100 words' do
      let(:overview) { Array.new(99, 'word').join(' ') }

      it 'reports the minimum' do
        expect(check.issues).to eq(
          [
            {
              message: 'Recipe overview should be at least 100 words long ' \
                       'for the recipe page to appear in Google and other search engines.'
            }
          ]
        )
      end
    end

    context 'when the overview has exactly 100 words across paragraphs' do
      let(:overview) { "#{Array.new(50, 'word').join(' ')}\n\n#{Array.new(50, 'word').join(' ')}" }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the overview is blank' do
      let(:overview) { '' }

      it 'passes because the setting is optional' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the overview is only whitespace' do
      let(:overview) { "  \n " }

      it 'passes because nothing is published' do
        expect(check.issues).to be_empty
      end
    end
  end
end
