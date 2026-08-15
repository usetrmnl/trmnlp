# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/form_field'

RSpec.describe TRMNLP::FormField do
  describe '.multi_select?' do
    it 'is true for a select with multiple: true' do
      expect(described_class.multi_select?('field_type' => 'select', 'multiple' => true)).to be(true)
    end

    it 'is nil for a single-select field' do
      expect(described_class.multi_select?('field_type' => 'select')).to be_nil
    end

    it 'is false for a non-select field' do
      expect(described_class.multi_select?('field_type' => 'text', 'multiple' => true)).to be(false)
    end
  end

  describe '.validate' do
    let(:valid_field) do
      { 'keyname' => 'api_key', 'name' => 'API Key', 'field_type' => 'password' }
    end

    it 'returns no warnings for a valid field' do
      expect(described_class.validate(valid_field)).to be_empty
    end

    it 'treats author_bio as a known field_type' do
      field = valid_field.merge('field_type' => 'author_bio')
      expect(described_class.validate(field)).to be_empty
    end

    it 'flags an unknown field_type' do
      field = valid_field.merge('field_type' => 'rocketship')
      expect(described_class.validate(field).first).to match(/unknown field_type/)
    end

    it 'flags a missing required key' do
      field = valid_field.except('name')
      expect(described_class.validate(field).first).to match(/missing required key: name/)
    end

    it 'does not reject unknown keys' do
      field = valid_field.merge('encrypted' => true, 'depends_on' => 'other')
      expect(described_class.validate(field)).to be_empty
    end
  end

  describe '.validate_all' do
    it 'aggregates warnings across every field' do
      fields = [
        { 'keyname' => 'a', 'name' => 'A' },
        { 'keyname' => 'b', 'name' => 'B', 'field_type' => 'nope' }
      ]
      expect(described_class.validate_all(fields).size).to eq(2)
    end

    it 'returns no warnings for nil' do
      expect(described_class.validate_all(nil)).to be_empty
    end
  end
end
