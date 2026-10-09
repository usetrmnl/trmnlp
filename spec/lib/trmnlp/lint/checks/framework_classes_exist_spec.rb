# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/framework_version'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/framework_classes_exist'

RSpec.describe TRMNLP::Lint::Checks::FrameworkClassesExist do
  subject(:check) { described_class.new(source) }

  let :source do
    instance_double TRMNLP::Lint::Source,
                    html_fragments: { 'src/full.liquid' => Nokogiri::HTML.fragment(markup) },
                    framework_version: TRMNLP::FrameworkVersion.new(version)
  end

  let(:version) { '3.4.0' }

  describe '#issues' do
    context 'with classes the Framework does not have' do
      let(:markup) { '<span class="value value--medium">1</span><span class="label--xsmall md:label--xsmall">a</span>' }

      it 'reports each class once' do
        expect(check.issues.map { it[:message][/\A'([^']+)'/, 1] }).to eq(%w[value--medium label--xsmall])
      end
    end

    context 'with a Rich Text size the Framework does not have' do
      let(:markup) { '<div class="content content--xsmall">1</div>' }

      it 'reports it' do
        expect(check.issues.map { it[:message][/\A'([^']+)'/, 1] }).to eq(%w[content--xsmall])
      end
    end

    context 'with Framework classes, screen prefixes and custom classes' do
      let :markup do
        '<b class="value value--xxsmall md:portrait:title--large text--gray-50 content--center my-value--medium">1</b>'
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a class whose name comes from Liquid output' do
      let(:markup) { '<span class="value--{{}}">1</span>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a class that a later release added' do
      let(:markup) { '<span class="text--bold">1</span>' }
      let(:version) { '2.3.7' }

      it 'reports it against the pinned release' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'with a release newer than the bundled list' do
      let(:markup) { '<span class="text--bold">1</span>' }
      let(:version) { '9.0.0' }

      it 'judges it against the newest list' do
        expect(check.issues).to be_empty
      end
    end
  end
end
