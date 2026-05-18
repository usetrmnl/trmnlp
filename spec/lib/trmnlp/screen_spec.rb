# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/screen'

RSpec.describe TRMNLP::Screen do
  describe '.all' do
    it 'lists every screen in display order' do
      expect(described_class.all.map(&:name)).to eq(%w[full half_horizontal half_vertical quadrant])
    end

    it 'is frozen' do
      expect(described_class.all).to be_frozen
    end
  end

  describe '.find' do
    it 'returns the matching Screen instance' do
      expect(described_class.find('quadrant')).to be(described_class::QUADRANT)
    end

    it 'returns nil for an unknown name' do
      expect(described_class.find('unknown')).to be_nil
    end
  end

  describe '.names' do
    it 'returns the string identifiers' do
      expect(described_class.names).to eq(%w[full half_horizontal half_vertical quadrant])
    end
  end

  describe '#mashup_classes' do
    it 'is nil for the full-screen layout' do
      expect(described_class::FULL.mashup_classes).to be_nil
    end

    it 'is the 1Tx1B layout for half_horizontal' do
      expect(described_class::HALF_HORIZONTAL.mashup_classes).to eq('mashup mashup--1Tx1B')
    end

    it 'is the 1Lx1R layout for half_vertical' do
      expect(described_class::HALF_VERTICAL.mashup_classes).to eq('mashup mashup--1Lx1R')
    end

    it 'is the 2x2 layout for quadrant' do
      expect(described_class::QUADRANT.mashup_classes).to eq('mashup mashup--2x2')
    end
  end
end
