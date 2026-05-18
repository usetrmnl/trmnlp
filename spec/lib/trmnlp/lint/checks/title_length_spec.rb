# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/title_length'

RSpec.describe TRMNLP::Lint::Checks::TitleLength do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, plugin_name: name) }

  describe '#issues' do
    context 'when the plugin name exceeds 50 characters' do
      let(:name) { 'A' * 51 }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the plugin name is within 50 characters' do
      let(:name) { 'Weather Widget' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
