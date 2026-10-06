# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_unknown_filters'

RSpec.describe TRMNLP::Lint::Checks::NoUnknownFilters do
  subject(:check) { described_class.new(source) }

  let(:source) do
    instance_double(TRMNLP::Lint::Source, local_only_filter_names: %w[shout],
                                          markup_files: { 'src/full.liquid' => markup })
  end

  describe '#issues' do
    context 'when an output uses a filter TRMNL does not have' do
      let(:markup) { '<p>{{ items | push: "more" | join: ", " }}</p>' }

      it 'names the filter' do
        expect(check.issues.first[:message]).to include("Filter 'push'")
      end
    end

    context 'when a tag uses a filter TRMNL does not have' do
      let(:markup) { '{% assign title = name | upcase | titleize %}' }

      it 'reports the use' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when markup uses the same unknown filter twice' do
      let(:markup) { '{{ a | titleize }}{{ b | titleize }}' }

      it 'reports the filter once' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when markup uses Liquid and TRMNL filters' do
      let(:markup) { '{{ total | number_with_delimiter | append: " steps" }}{{ url | qr_code }}' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when markup uses a filter only custom_filters defines' do
      let(:markup) { '{{ title | shout }}' }

      it 'leaves it to no_custom_filters' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a pipe appears inside a string' do
      let(:markup) { '{{ "red | green" | split: " | " | first }}' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a filter appears inside a raw block' do
      let(:markup) { '{% raw %}{{ value | titleize }}{% endraw %}' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the markup does not parse' do
      let(:markup) { '{% if %}{{ value | titleize }}' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
