# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/coordinates_use_lat_lon'

RSpec.describe TRMNLP::Lint::Checks::CoordinatesUseLatLon do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, custom_field_definitions: keynames.map { { 'keyname' => it } }) }

  describe '#issues' do
    context 'when there are separate latitude and longitude fields' do
      let(:keynames) { %w[latitude longitude] }

      it 'names both fields' do
        expect(check.issues.first[:message]).to include("'latitude' and 'longitude'")
      end

      it 'links to the lat_lon field docs' do
        expect(check.issues.first[:learn_more]).to eq(described_class::LEARN_MORE)
      end
    end

    context 'when the keynames use short forms with a prefix' do
      let(:keynames) { %w[home_lat home_lng] }

      it 'reports the fields' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when the keynames are camel case' do
      let(:keynames) { %w[homeLat homeLon] }

      it 'reports the fields' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when there is only a latitude field' do
      let(:keynames) { %w[lat] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a keyname only contains lat or long inside a word' do
      let(:keynames) { %w[template longest_route] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when one field is already a lat_lon field' do
      let(:source) do
        instance_double(TRMNLP::Lint::Source,
                        custom_field_definitions: [{ 'keyname' => 'lat_lon', 'field_type' => 'lat_lon' }])
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when two lat_lon fields have latitude and longitude keynames' do
      let(:source) do
        instance_double(TRMNLP::Lint::Source, custom_field_definitions: [
                          { 'keyname' => 'home_lat', 'field_type' => 'lat_lon' },
                          { 'keyname' => 'work_lng', 'field_type' => 'lat_lon' }
                        ])
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when one keyname names both latitude and longitude' do
      let(:keynames) { %w[lat_lng] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when there are no custom field definitions' do
      let(:keynames) { [] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
