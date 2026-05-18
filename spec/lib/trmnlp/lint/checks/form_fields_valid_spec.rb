# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/form_fields_valid'

RSpec.describe TRMNLP::Lint::Checks::FormFieldsValid do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, custom_field_definitions: definitions) }

  describe '#issues' do
    context 'when a custom field definition is missing required keys' do
      let(:definitions) { [{ 'keyname' => 'broken' }] }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
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
