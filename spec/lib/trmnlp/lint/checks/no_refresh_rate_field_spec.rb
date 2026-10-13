# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_refresh_rate_field'

RSpec.describe TRMNLP::Lint::Checks::NoRefreshRateField do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, custom_field_definitions: [field]) }

  describe '#issues' do
    context 'when a select picks how often the content changes' do
      let(:field) do
        { 'keyname' => 'rotation', 'field_type' => 'select', 'name' => 'New passage',
          'options' => [{ 'Daily' => 'daily' }, { 'Twice a day' => 'twelve_hours' },
                        { 'Every 6 hours' => 'six_hours' }] }
      end

      it 'names the field and the refresh rate' do
        expect(check.issues.first[:message]).to include("'rotation'", 'refresh rate')
      end
    end

    context 'when the options carry a note after the interval' do
      let(:field) do
        { 'keyname' => 'rotation', 'field_type' => 'select', 'name' => 'New Machine',
          'options' => [{ 'Once a day (midnight, your time)' => 'daily' }, { 'Every hour' => '1h' },
                        { 'Shuffle' => 'shuffle' }] }
      end

      it 'reports the field' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when a number field sets a refresh interval in minutes' do
      let(:field) { { 'keyname' => 'refresh_interval', 'field_type' => 'number', 'name' => 'Refresh every (minutes)' } }

      it 'reports the field' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when the interval is data, such as a bin collected every 2 weeks' do
      let(:field) do
        { 'keyname' => 'bin1_every', 'field_type' => 'select', 'name' => 'Bin 1: collected every',
          'options' => [{ 'Week' => '1' }, { '2 weeks' => '2' }] }
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when only the description says the content changes' do
      let(:field) do
        { 'keyname' => 'area', 'field_type' => 'select', 'name' => 'Region',
          'description' => 'Tick one or more to take turns, a new range each day.',
          'options' => [{ 'Europe' => 'europe' }] }
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a rotating field picks what to show, not how often' do
      let(:field) do
        { 'keyname' => 'focus', 'field_type' => 'select', 'name' => 'Focus',
          'options' => [{ 'Everything, rotating' => 'everything' }, { 'Play ideas' => 'play' }] }
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
