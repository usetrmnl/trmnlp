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

    it 'defines window.I18n.andXMore' do
      expect(rendered).to include('window.I18n = { andXMore:')
    end

    it 'signals when Highcharts has drawn, which the PNG capture waits for' do
      expect(rendered).to include('window.TRMNL_HIGHCHARTS_DONE = true')
    end

    it 'links the stylesheet of a picked theme' do
      allow(config.plugin).to receive(:framework_version).and_return(TRMNLP::FrameworkVersion.new('3.4.0'))

      expect(renderer.render_full_page('full', theme: 'dark')).to include('https://trmnl.com/css/3.4.0/themes/dark-theme.css')
    end
  end

  describe '#render_liquid_template' do
    it 'raises RenderError when the template is missing' do
      expect { renderer.send(:render_liquid_template, 'nonexistent') }
        .to raise_error(TRMNLP::RenderError, /Missing template/)
    end
  end

  describe '#screen_classes' do
    it 'adds the TRMNL font a new device renders with' do
      expect(renderer.screen_classes).to eq('screen screen--fonts-trmnl')
    end

    it 'keeps a font the picker chose' do
      expect(renderer.screen_classes('screen screen--fonts-classic')).to eq('screen screen--fonts-classic')
    end

    it 'appends screen--no-bleed when no_screen_padding is enabled' do
      allow(config.plugin).to receive(:no_screen_padding).and_return('yes')
      expect(renderer.screen_classes).to eq('screen screen--no-bleed screen--fonts-trmnl')
    end

    it 'adds both dark mode classes when the plugin settings enable dark mode' do
      allow(config.plugin).to receive(:dark_mode).and_return('yes')
      expect(renderer.screen_classes).to eq('screen screen--dark-mode dark-mode screen--fonts-trmnl')
    end

    it 'drops the screen--1x the picker adds, which a device render never has' do
      expect(renderer.screen_classes('screen screen--1x')).to eq('screen screen--fonts-trmnl')
    end

    it 'adds a known theme' do
      expect(renderer.screen_classes('screen', theme: 'dark')).to eq('screen screen--fonts-trmnl screen--theme-dark')
    end

    it 'ignores an unknown theme' do
      expect(renderer.screen_classes('screen', theme: '"><script>')).to eq('screen screen--fonts-trmnl')
    end

    it 'adds the bare dark-mode class Framework 1.x inverts on to a picked dark mode' do
      expect(renderer.screen_classes('screen screen--dark-mode'))
        .to eq('screen screen--dark-mode dark-mode screen--fonts-trmnl')
    end
  end

  describe '#and_x_more' do
    it 'answers the English phrase by default' do
      expect(renderer.and_x_more).to eq(%w[And more])
    end

    it "answers the phrase for the user's locale" do
      allow(config.project).to receive(:user_data_overrides).and_return('trmnl' => { 'user' => { 'locale' => 'nl' } })

      expect(renderer.and_x_more).to eq(['En nog', 'more'])
    end

    it 'falls back to the language of a regional locale' do
      allow(config.project).to receive(:user_data_overrides)
        .and_return('trmnl' => { 'user' => { 'locale' => 'de-CH' } })

      expect(renderer.and_x_more).to eq(%w[und weitere])
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
