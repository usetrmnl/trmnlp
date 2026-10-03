# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNL::Liquid do
  describe 'registered filters' do
    subject(:rendered) { Liquid::Template.parse(markup, environment: described_class.new).render }

    context 'with pluralize and an explicit plural' do
      let(:markup) { %q({{ "person" | pluralize: 4, plural: 'people' }}) }

      it { expect(rendered).to eq('4 people') }
    end

    context 'with pluralize and an irregular noun' do
      let(:markup) { '{{ "person" | pluralize: 3 }}' }

      it { expect(rendered).to eq('3 people') }
    end

    context 'with l_word in English' do
      let(:markup) { '{{ "today" | l_word: "en" }}' }

      it { expect(rendered).to eq('today') }
    end

    context 'with l_word in another locale' do
      let(:markup) { '{{ "today" | l_word: "de" }}' }

      it { expect(rendered).to eq('Heute') }
    end

    context 'with l_word in a non-Latin locale' do
      let(:markup) { '{{ "today" | l_word: "ja" }}' }

      it { expect(rendered).to eq('今日') }
    end

    context 'with l_word in a locale TRMNL does not offer' do
      let(:markup) { '{{ "today" | l_word: "fr-CA" }}' }

      it { expect(rendered).to eq('Liquid error: "fr-CA" is not a valid locale') }
    end

    context 'with l_word in a locale that lacks the word' do
      let(:markup) { '{{ "today" | l_word: "en-GB" }}' }

      it { expect(rendered).to eq('today') }
    end

    context 'with pluralize and a count of one written as a decimal' do
      let(:markup) { '{{ "child" | pluralize: "1.0" }}' }

      it { expect(rendered).to eq('1.0 child') }
    end

    context 'with pluralize and no count' do
      let(:markup) { '{{ "child" | pluralize: nothing }}' }

      it { expect(rendered).to eq('0 children') }
    end

    context 'with l_date in another locale' do
      let(:markup) { '{{ "2026-03-05" | l_date: "%A %d %B", "fr" }}' }

      it { expect(rendered).to eq('jeudi 05 mars') }
    end

    context 'with number_to_currency and a locale' do
      let(:markup) { '{{ 1234.5 | number_to_currency: "de" }}' }

      it { expect(rendered).to eq('1,234.50 €') }
    end

    context 'with number_to_currency and a locale that puts the unit first' do
      let(:markup) { '{{ 1234.5 | number_to_currency: "en-GB" }}' }

      it { expect(rendered).to eq('£1,234.50') }
    end

    context 'with number_to_currency and a locale without a space before the unit' do
      let(:markup) { '{{ 1234.5 | number_to_currency: "ja" }}' }

      it { expect(rendered).to eq('1,234.50円') }
    end

    context 'with number_to_currency and a locale TRMNL does not offer' do
      let(:markup) { '{{ 1234.5 | number_to_currency: "fr-CA" }}' }

      it { expect(rendered).to eq('fr-CA1,234.50') }
    end

    context 'with number_to_currency and no number' do
      let(:markup) { '{{ nothing | number_to_currency }}' }

      it { expect(rendered).to eq('') }
    end

    context 'with number_to_currency and a unit holding HTML' do
      let(:markup) { '{{ 5 | number_to_currency: "R&D<" }}' }

      it { expect(rendered).to eq('R&amp;D&lt;5.00') }
    end

    context 'with number_with_delimiter and custom marks' do
      let(:markup) { '{{ 1234567.5 | number_with_delimiter: ".", "," }}' }

      it { expect(rendered).to eq('1.234.567,5') }
    end

    context 'with number_to_currency and a unit' do
      let(:markup) { '{{ 1234.5 | number_to_currency: "£" }}' }

      it { expect(rendered).to eq('£1,234.50') }
    end
  end
end
