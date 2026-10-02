# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/arbitrary_values_in_range'
require 'trmnlp/framework_version'

RSpec.describe TRMNLP::Lint::Checks::ArbitraryValuesInRange do
  subject(:check) { described_class.new(source) }

  let(:source) do
    instance_double(TRMNLP::Lint::Source, all_markup: markup, framework_version: TRMNLP::FrameworkVersion.new(version))
  end
  let(:version) { '3.4.0' }
  let(:messages) { check.issues.map { |issue| issue[:message] } }

  describe '#issues' do
    context 'when every bracketed value is in range' do
      let(:markup) do
        '<div class="w--[128px] lg:h--max-[0px] w--[50cqw] h--[100cqh] gap--[50px] rounded--[8px]"></div>'
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a size is past 128px' do
      let(:markup) { '<img class="lg:w--max-[192px]">' }

      it 'names the class and the range' do
        expect(messages).to eq(
          ["'lg:w--max-[192px]' has no effect: the Framework generates 'w--max-[Npx]' from 0 to 128 in whole numbers."]
        )
      end
    end

    context 'when a gap or radius is past 50px' do
      let(:markup) { '<div class="gap--[60px]"><span class="rounded--[51px]"></span></div>' }

      it 'reports each one' do
        expect(messages.size).to eq(2)
      end
    end

    context 'when a value is fractional' do
      let(:markup) { '<div class="w--[10.5px]"></div>' }

      it 'reports it' do
        expect(messages.size).to eq(1)
      end
    end

    context 'when the unit does not belong to the family' do
      let(:markup) { '<div class="h--[50cqw] gap--[10cqw]"></div>' }

      it 'reports both' do
        expect(messages).to all(include('has no'))
        expect(messages.size).to eq(2)
      end
    end

    context 'when a gap carries a screen prefix' do
      let(:markup) { '<div class="md:gap--[20px]"></div>' }

      it 'reports the prefix' do
        expect(messages).to eq(["'md:gap--[20px]' has no effect: 'gap--[Npx]' takes no screen prefix."])
      end
    end

    context 'when a gap carries a screen prefix on Framework 3.1' do
      let(:markup) { '<div class="md:gap--[20px]"></div>' }
      let(:version) { '3.1.8' }

      it 'passes because 3.1 still generated prefixed gaps' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the plugin is on Framework 2' do
      let(:markup) { '<div class="w--[240px]"></div>' }
      let(:version) { '2.3.7' }

      it 'passes because v2 generated wider sizes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the same class repeats' do
      let(:markup) { '<i class="w--[200px]"></i><i class="w--[200px]"></i>' }

      it 'reports it once' do
        expect(messages.size).to eq(1)
      end
    end

    context 'when the value is a Liquid expression' do
      let(:markup) { '<div class="w--[{{ width }}px]"></div>' }

      it 'leaves it alone' do
        expect(check.issues).to be_empty
      end
    end
  end
end
