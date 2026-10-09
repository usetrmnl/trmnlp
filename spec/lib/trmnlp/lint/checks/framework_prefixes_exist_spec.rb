# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/framework_version'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/framework_prefixes_exist'

RSpec.describe TRMNLP::Lint::Checks::FrameworkPrefixesExist do
  subject(:check) { described_class.new(source) }

  let :source do
    instance_double TRMNLP::Lint::Source,
                    html_fragments: { 'src/full.liquid' => Nokogiri::HTML.fragment(markup) },
                    framework_version: TRMNLP::FrameworkVersion.new(version)
  end

  let(:version) { '3.4.0' }

  def reported = check.issues.map { it[:message][/\A'([^']+)'/, 1] }

  describe '#issues' do
    context 'with a prefix the Framework does not have' do
      let(:markup) { '<span class="value xl:value--large tablet:value--small">1</span>' }

      it 'reports each class' do
        expect(reported).to eq(%w[xl:value--large tablet:value--small])
      end
    end

    context 'with prefixes out of order' do
      let(:markup) { '<span class="value portrait:lg:value--large">1</span>' }

      it 'gives the order that works' do
        expect(check.issues.first[:message]).to include("'lg:portrait:value--large'")
      end
    end

    context 'with a prefix the class has no variant for' do
      let(:markup) { '<span class="value dark:value--large">1</span>' }

      it 'reports it' do
        expect(reported).to eq(%w[dark:value--large])
      end
    end

    context 'with a prefix the class has no variant for, though others in its family do' do
      let(:markup) { '<span class="dark:text--bold dark:text--gray-50">1</span>' }

      it 'reports only that class' do
        expect(reported).to eq(%w[dark:text--bold])
      end
    end

    context 'with a prefix a later release removed' do
      let(:markup) { '<span class="md:3bit:text--blue-50">1</span>' }

      it 'reports it' do
        expect(reported).to eq(%w[md:3bit:text--blue-50])
      end
    end

    context 'with a prefix the pinned release still had' do
      let(:markup) { '<span class="md:3bit:text--blue-50">1</span>' }
      let(:version) { '3.1.1' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with prefixes the Framework has' do
      let :markup do
        '<b class="sm:value--small md:portrait:title--large lg:2bit:value--xlarge ' \
          'dark:md:portrait:2bit:text--gray-50 lg:portrait:content--large">1</b>'
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a bit depth prefix on its own' do
      let(:markup) { '<span class="2bit:text--gray-30 4bit:text--gray-45">1</span>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a class the Framework does not have' do
      let(:markup) { '<span class="xl:value--medium">1</span>' }

      it 'leaves it to framework_classes_exist' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a prefix that comes from Liquid output' do
      let(:markup) { '<span class="{{ size }}:value--large">1</span>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a prefix the Framework does not have, for the docs link' do
      let(:markup) { '<span class="xl:value--large">1</span>' }

      it 'links to the Responsive page' do
        expect(check.issues.first[:learn_more]).to eq('https://trmnl.com/framework/docs/responsive')
      end
    end
  end
end
