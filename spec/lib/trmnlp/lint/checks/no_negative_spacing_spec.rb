# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_negative_spacing'

RSpec.describe TRMNLP::Lint::Checks::NoNegativeSpacing do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }
  let(:messages) { check.issues.map { |issue| issue[:message] } }

  describe '#issues' do
    context 'when spacing and positions are positive' do
      let(:markup) { '<div class="mt--2 lg:px--4 gap--small top--1 inset--0 order---1 flex--col-reverse"></div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a margin has a leading minus' do
      let(:markup) { '<img class="w--[16px] -mt--1">' }

      it 'names the class and the spacing docs' do
        expect(check.issues).to eq(
          [{ message: "'-mt--1' has no effect: the Framework has no negative 'mt--' classes.",
             learn_more: 'https://trmnl.com/framework/docs/spacing' }]
        )
      end
    end

    context 'when the class carries screen prefixes' do
      let(:markup) { '<div class="lg:-ml--2 md:portrait:-top--0.5"></div>' }

      it 'reports each with its prefixes' do
        expect(messages.map { it[/\A'[^']+'/] }).to eq(["'lg:-ml--2'", "'md:portrait:-top--0.5'"])
      end
    end

    context 'when padding, gap and insets are negative' do
      let(:markup) { '<div class="-p--1 -gap--small -inset--2 -right--3"></div>' }

      it 'reports all of them' do
        expect(messages.size).to eq(4)
      end
    end

    context 'when the same class repeats' do
      let(:markup) { '<i class="-mb--1"></i><i class="-mb--1"></i>' }

      it 'reports it once' do
        expect(messages.size).to eq(1)
      end
    end

    context 'when a minus is part of another word' do
      let(:markup) { '<div class="item-mt--2 x--mt--1" data-offset="a-top--1"></div>' }

      it 'leaves it alone' do
        expect(check.issues).to be_empty
      end
    end
  end
end
