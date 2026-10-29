# frozen_string_literal: true

require 'tmpdir'
require 'spec_helper'
require 'trmnlp/paths'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/framework_elements_used'

RSpec.describe TRMNLP::Lint::Checks::FrameworkElementsUsed do
  subject(:check) { described_class.new(source) }

  let(:root) { Pathname(Dir.mktmpdir) }
  let(:source) { TRMNLP::Lint::Source.new(config: nil, paths: TRMNLP::Paths.new(root)) }

  before do
    root.join('src').mkpath
    root.join('src/settings.yml').write("name: Test\n")
    root.join('src/full.liquid').write(markup)
  end

  after { FileUtils.remove_entry(root) }

  describe '#issues' do
    context 'when a <style> block draws the text without a framework element' do
      let(:markup) { '<style>.big { font-size: 40px }</style><div class="big">72°</div>' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the text uses a framework element with a prefix' do
      let(:markup) { '<style>.big { color: black }</style><div class="lg:value--xlarge">72°</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the only <style> block is inside a Liquid comment' do
      let(:markup) { '{% comment %}<style>.big { font-size: 40px }</style>{% endcomment %}<div class="big">72°</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the markup has no <style> block' do
      let(:markup) { '<div class="big">72°</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
