# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/title_casing'

RSpec.describe TRMNLP::Lint::Checks::TitleCasing do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, plugin_name: name) }

  describe '#issues' do
    context 'when the plugin name starts with a lowercase letter' do
      let(:name) { 'weather widget' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the plugin name starts with a capital letter' do
      let(:name) { 'Weather Widget' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
