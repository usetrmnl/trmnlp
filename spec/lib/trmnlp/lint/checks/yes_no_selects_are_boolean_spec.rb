# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/yes_no_selects_are_boolean'

RSpec.describe TRMNLP::Lint::Checks::YesNoSelectsAreBoolean do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, custom_field_definitions: definitions) }
  let(:definitions) { [{ 'keyname' => 'show_icons', 'field_type' => 'select', 'options' => options }] }

  describe '#issues' do
    context 'when a select has only Yes and No options' do
      let(:options) { %w[Yes No] }

      it 'names the field' do
        expect(check.issues.first[:message]).to include("'show_icons'")
      end
    end

    context 'when the options are Label: value pairs' do
      let(:options) { [{ 'Yes' => 'yes' }, { 'No' => 'no' }] }

      it 'reports the field' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when unquoted YAML parses yes and no as booleans' do
      let(:options) { [true, false] }

      it 'reports the field' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when a select has a third option' do
      let(:options) { %w[Yes No Maybe] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a select has only one of yes and no' do
      let(:options) { %w[Yes] }

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

    context 'when a field that is not a select has yes and no options' do
      let(:definitions) { [{ 'keyname' => 'mode', 'field_type' => 'string', 'options' => %w[Yes No] }] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when there are no custom field definitions' do
      let(:definitions) { [] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
