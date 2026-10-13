# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/gray_text_has_one_bit_class'

RSpec.describe TRMNLP::Lint::Checks::GrayTextHasOneBitClass do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, html_fragments: { 'src/full.liquid' => Nokogiri::HTML.fragment(markup) }) }

  describe '#issues' do
    context 'when small text is gray with no 1bit: class' do
      let(:markup) { '<span class="label label--small text--gray-30">Next up</span>' }

      it 'names the classes' do
        expect(check.issues.first[:message]).to include("'label label--small text--gray-30'", '1bit:text--black')
      end
    end

    context 'with label--gray on a small label' do
      let(:markup) { '<span class="label label--small label--gray">Next up</span>' }

      it 'reports the issue' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'with two different gray class lists' do
      let(:markup) { '<span class="text--small text--gray-20">A</span><span class="text--xsmall text--gray">B</span>' }

      it 'reports each class list' do
        expect(check.issues.size).to eq(2)
      end
    end

    context 'with the same class list on two elements' do
      let(:markup) do
        '<span class="text--small text--gray-20">A</span><span class="text--small text--gray-20">B</span>'
      end

      it 'reports it once' do
        expect(check.issues.size).to eq(1)
      end
    end

    context 'when the element has a 1bit: class' do
      let(:markup) { '<span class="label label--small text--gray-30 1bit:text--black">Next up</span>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when a value is small and gray, such as initials in an avatar' do
      let(:markup) { '<div class="bg--gray-75 text--gray-10 value value--xsmall">AB</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the gray or the size only applies on large screens' do
      let(:markup) { '<span class="label label--small lg:text--gray-55">Next up</span>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
