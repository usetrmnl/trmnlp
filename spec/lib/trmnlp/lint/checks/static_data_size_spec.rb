# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/static_data_size'

RSpec.describe TRMNLP::Lint::Checks::StaticDataSize do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, static_data:) }

  # JSON.generate({ 'verses' => 'x' * n }) is n + 13 bytes.
  def data_of(bytes) = { 'verses' => 'x' * (bytes - 13) }

  describe '#issues' do
    context 'when static_data is over 100 KB' do
      let(:static_data) { data_of((100 * 1024) + 1) }

      it 'reports the size and the limit' do
        expect(check.issues).to eq([{ message: 'static_data is 102401 bytes; TRMNL rejects static data over 100 KB.' }])
      end
    end

    context 'when static_data is exactly 100 KB' do
      let(:static_data) { data_of(100 * 1024) }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the plugin has no static_data' do
      let(:static_data) { {} }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
