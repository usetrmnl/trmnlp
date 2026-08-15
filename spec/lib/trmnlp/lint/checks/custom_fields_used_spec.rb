# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/custom_fields_used'

RSpec.describe TRMNLP::Lint::Checks::CustomFieldsUsed do
  subject(:check) { described_class.new(source) }

  let(:source) do
    instance_double(TRMNLP::Lint::Source, custom_field_values: field_values, settings: {}, all_markup: markup)
  end

  describe '#issues' do
    context 'when a custom field never appears in the markup or settings' do
      let(:field_values) { { 'ghost' => 'value' } }
      let(:markup) { '<p>unrelated content</p>' }

      it 'reports the unused field' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when a custom field is referenced in the markup' do
      let(:field_values) { { 'headline' => 'value' } }
      let(:markup) { '<p>{{ headline }}</p>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
