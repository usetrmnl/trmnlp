# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/description_length'

RSpec.describe TRMNLP::Lint::Checks::DescriptionLength do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, plugin_description: description) }

  describe '#issues' do
    context 'when the description exceeds 35 characters' do
      let(:description) { 'A' * 36 }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the description is exactly 35 characters' do
      let(:description) { 'A' * 35 }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the description is within 35 characters' do
      let(:description) { 'Top stories from Hacker News' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    # A description is optional — only its length is validated.
    context 'when the description is empty' do
      let(:description) { '' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
