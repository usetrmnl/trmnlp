# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::Renderer do
  subject(:renderer) { described_class.new(config:, paths:, user_data_assembler:) }

  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:transform_pipeline) { TRMNLP::TransformPipeline.new(config:, paths:) }
  let(:user_data_assembler) { TRMNLP::UserDataAssembler.new(config:, paths:, transform_pipeline:) }

  describe '#render_full_page' do
    # The fixtures plugin has no src/*.liquid, so the Liquid step falls back
    # to "Missing template: ..." — but the full ERB pipeline still runs.
    let(:rendered) { renderer.render_full_page('full') }

    it 'returns the ERB-rendered HTML containing the liquid fallback' do
      expect(rendered).to include('Missing template:')
      expect(rendered).to include('src/full.liquid')
    end

    it 'wires the view name into the ERB binding' do
      expect(rendered).to include('view--full')
    end
  end

  describe '#render_liquid_template' do
    it 'raises RenderError when the template is missing' do
      expect { renderer.send(:render_liquid_template, 'nonexistent') }
        .to raise_error(TRMNLP::RenderError, /Missing template/)
    end
  end

  describe '#screen_classes' do
    it 'returns the default class when no_screen_padding is unset' do
      expect(renderer.screen_classes).to eq('screen')
    end

    it 'appends screen--no-bleed when no_screen_padding is enabled' do
      allow(config.plugin).to receive(:no_screen_padding).and_return('yes')
      expect(renderer.screen_classes).to eq('screen screen--no-bleed')
    end
  end

  describe '#framework' do
    it 'reads the framework version from the plugin config' do
      framework = TRMNLP::FrameworkVersion.new('latest')
      allow(config.plugin).to receive(:framework_version).and_return(framework)
      expect(renderer.framework).to be(framework)
    end
  end
end
