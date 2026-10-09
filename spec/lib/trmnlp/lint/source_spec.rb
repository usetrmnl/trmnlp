# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'

RSpec.describe TRMNLP::Lint::Source do
  subject(:source) { described_class.new(config:, paths: nil) }

  let(:config) { instance_double(TRMNLP::Config, plugin: plugin_config) }
  let(:plugin_config) { instance_double(TRMNLP::Config::Plugin, settings:) }

  describe '#plugin_description' do
    context 'when settings.yml sets a description' do
      let(:settings) { { 'description' => 'Top stories from HN' } }

      it 'answers the value' do
        expect(source.plugin_description).to eq('Top stories from HN')
      end
    end

    context 'when settings.yml omits the key' do
      let(:settings) { { 'name' => 'Hacker News' } }

      it 'answers an empty string' do
        expect(source.plugin_description).to eq('')
      end
    end

    context 'when the key is present with no value' do
      let(:settings) { { 'description' => nil } }

      it 'answers an empty string' do
        expect(source.plugin_description).to eq('')
      end
    end
  end

  describe '#recipe_overview' do
    context 'when settings.yml sets an overview' do
      let(:settings) { { 'recipe_overview' => "Top stories.\n\nRefreshed hourly." } }

      it 'answers the value with its line breaks' do
        expect(source.recipe_overview).to eq("Top stories.\n\nRefreshed hourly.")
      end
    end

    context 'when settings.yml omits the key' do
      let(:settings) { { 'name' => 'Hacker News' } }

      it 'answers an empty string' do
        expect(source.recipe_overview).to eq('')
      end
    end
  end

  describe '#framework_version' do
    let(:settings) { {} }
    let(:version) { TRMNLP::FrameworkVersion.new('3.4.0') }

    before { allow(plugin_config).to receive(:framework_version).and_return(version) }

    it "answers the plugin's framework version" do
      expect(source.framework_version).to eq(version)
    end
  end

  describe '#local_only_filter_names' do
    let(:settings) { {} }
    let(:config) { instance_double(TRMNLP::Config, plugin: plugin_config, project:) }
    let(:project) { instance_double(TRMNLP::Config::Project, user_filter_modules: [filter_module]) }

    let :filter_module do
      Module.new do
        def shout(input) = input
        def upcase(input) = input
      end
    end

    it 'answers the custom filters that trmnl-liquid does not provide' do
      expect(source.local_only_filter_names).to eq(%w[shout])
    end
  end

  describe '#transform_code' do
    subject(:source) { described_class.new(config: nil, paths:) }

    let(:paths) { instance_double(TRMNLP::Paths, transform_file:) }

    context 'when src has a transform file' do
      let(:file) { instance_double(Pathname, exist?: true, read: "  function run(input) {}\n") }
      let(:transform_file) { [file, 'node'] }

      it 'answers its stripped contents' do
        expect(source.transform_code).to eq('function run(input) {}')
      end
    end

    context 'when src has no transform file' do
      let(:transform_file) { [nil, nil] }

      it 'answers an empty string' do
        expect(source.transform_code).to eq('')
      end
    end
  end

  describe '#html_fragments' do
    subject(:source) { described_class.new(config: nil, paths:) }

    let(:paths) { instance_double(TRMNLP::Paths) }
    let(:file) { instance_double(Pathname, exist?: true, read: markup) }
    let(:classes) { source.html_fragments.fetch('src/shared.liquid').css('[class]').map { it['class'] } }

    before do
      allow(paths).to receive(:template).and_return(instance_double(Pathname, exist?: false))
      allow(paths).to receive(:template).with('shared').and_return(file)
    end

    context 'with Liquid output inside a class attribute' do
      let(:markup) { %(<div class="value--{{ size | default: "large" }} label">1</div>) }

      it 'keeps the attribute whole with a placeholder for the output' do
        expect(classes).to eq(['value--{{}} label'])
      end
    end

    context 'with Liquid tags inside a class attribute' do
      let(:markup) { '<div class="{% if big %}value--large{% else %}value--small{% endif %}">1</div>' }

      it 'keeps the classes of every branch' do
        expect(classes).to eq([' value--large value--small '])
      end
    end

    context 'with markup inside a Liquid comment' do
      let(:markup) { '{% comment %}<div class="layout"></div>{% endcomment %}' }

      it 'leaves it out' do
        expect(classes).to be_empty
      end
    end
  end
end
