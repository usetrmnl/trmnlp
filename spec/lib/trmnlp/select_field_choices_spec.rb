# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::SelectFieldChoices do
  subject(:choices) { described_class.new('options' => ['New York', { 'Metric units' => 'si' }]) }

  it 'saves a plain option lowercased with underscores' do
    expect(choices.pairs.first).to eq(['New York', 'new_york'])
  end

  it 'saves a labelled option as its value' do
    expect(choices.pairs.last).to eq(['Metric units', 'si'])
  end

  it 'turns a label into its value' do
    expect(choices.stored_value('New York')).to eq('new_york')
  end

  it 'keeps a value' do
    expect(choices.stored_value('si')).to eq('si')
  end

  it 'keeps what the options do not list' do
    expect(choices.stored_value('Paris')).to eq('Paris')
  end

  it 'turns each label of a multi-select into its value' do
    expect(choices.stored_value(['New York', 'Metric units'])).to eq(%w[new_york si])
  end

  it 'answers no pairs without options' do
    expect(described_class.new({}).pairs).to eq([])
  end
end
