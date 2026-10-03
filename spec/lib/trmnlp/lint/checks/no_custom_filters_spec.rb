# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_custom_filters'

RSpec.describe TRMNLP::Lint::Checks::NoCustomFilters do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, local_only_filter_names: %w[shout], all_markup: markup) }

  describe '#issues' do
    context 'when an output uses a custom filter' do
      let(:markup) { '<p>{{ title | shout }}</p>' }

      it 'names the filter' do
        expect(check.issues.first[:message]).to include("Filter 'shout'")
      end
    end

    context 'when a tag uses a custom filter' do
      let(:markup) { '{% assign loud = title | upcase | shout %}' }

      it 'reports the use' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when markup uses only a filter with a longer name' do
      let(:markup) { '{{ title | shout_twice }}' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the name follows a pipe outside Liquid' do
      let(:markup) { '<script>const value = cached || shout;</script>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
