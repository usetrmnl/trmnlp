# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/select_options_split_label_and_value'

RSpec.describe TRMNLP::Lint::Checks::SelectOptionsSplitLabelAndValue do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, custom_field_definitions: definitions) }
  let(:definitions) { [{ 'keyname' => 'probe', 'field_type' => 'select', 'options' => options }] }

  describe '#issues' do
    context "when an option is one quoted string 'Label: value'" do
      let(:options) { ['Voyager 1: voyager1', 'Parker Solar Probe: parker'] }

      it 'names the field and the value TRMNL would save' do
        expect(check.issues.first[:message]).to include("'probe'", "'Voyager 1: voyager1'", "'voyager_1:_voyager1'")
      end

      it 'reports the field once' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when the options are Label: value pairs' do
      let(:options) { [{ 'Voyager 1' => 'voyager1' }, { 'Parker Solar Probe' => 'parker' }] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when an option has a colon with no space after it' do
      let(:options) { %w[12:00 16:9] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when options is not a list' do
      let(:options) { '__dynamic_options__' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a field that is not a select has such an option' do
      let(:definitions) { [{ 'keyname' => 'mode', 'field_type' => 'string', 'options' => ['A: a'] }] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
