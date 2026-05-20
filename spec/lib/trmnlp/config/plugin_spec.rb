# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe TRMNLP::Config::Plugin do
  subject(:plugin) { described_class.new(paths, project_config) }

  let(:root_dir) { File.join(__dir__, '../../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  let(:project_config) { TRMNLP::Config::Project.new(paths) }

  describe '#polling_headers' do
    context 'with a plain key=value pair' do
      before { plugin.instance_variable_set(:@config, { 'polling_headers' => 'Authorization=Bearer abc' }) }

      it 'parses into a hash' do
        expect(plugin.polling_headers).to eq({ 'Authorization' => 'Bearer abc' })
      end
    end

    context 'with a Liquid conditional that spans the whole string' do
      before do
        config = { 'polling_headers' => '{% if character_name %}Greeting=hello {{ character_name }}{% endif %}' }
        plugin.instance_variable_set(:@config, config)
      end

      it 'renders the conditional before parsing key=value pairs (issue #79)' do
        expect(plugin.polling_headers).to eq({ 'Greeting' => 'hello Bluey' })
      end
    end

    context 'with a Liquid conditional whose render is empty' do
      before do
        config = { 'polling_headers' => '{% if missing_field %}Authorization=Bearer {{ missing_field }}{% endif %}' }
        plugin.instance_variable_set(:@config, config)
      end

      it 'returns an empty hash' do
        expect(plugin.polling_headers).to eq({})
      end
    end
  end

  describe '#framework_version' do
    context 'when settings.yml pins a version' do
      let(:pinned) { TRMNLP::FrameworkVersion.version_numbers.first }
      before { plugin.instance_variable_set(:@config, { 'framework_version' => pinned }) }

      it 'resolves that pinned version' do
        expect(plugin.framework_version).to eq(TRMNLP::FrameworkVersion.new(pinned))
      end
    end

    context 'when settings.yml omits framework_version' do
      before { plugin.instance_variable_set(:@config, {}) }

      it 'falls back to the latest version' do
        expect(plugin.framework_version).to eq(TRMNLP::FrameworkVersion.latest)
      end
    end

    context 'when settings.yml names an unknown version' do
      before { plugin.instance_variable_set(:@config, { 'framework_version' => '9.9.9' }) }

      it 'raises a typed InvalidConfig error' do
        expect { plugin.framework_version }.to raise_error(TRMNLP::InvalidConfig, /9\.9\.9/)
      end
    end
  end

  describe '#custom_field_definitions' do
    context 'when settings.yml declares custom_fields' do
      let(:fields) { [{ 'keyname' => 'api_key', 'name' => 'API Key', 'field_type' => 'password' }] }
      before { plugin.instance_variable_set(:@config, { 'custom_fields' => fields }) }

      it 'returns the declared definitions' do
        expect(plugin.custom_field_definitions).to eq(fields)
      end
    end

    context 'when settings.yml omits custom_fields' do
      before { plugin.instance_variable_set(:@config, {}) }

      it 'returns an empty list' do
        expect(plugin.custom_field_definitions).to eq([])
      end
    end
  end

  describe '#serverless_language' do
    context 'when settings.yml sets a language' do
      before { plugin.instance_variable_set(:@config, { 'serverless_language' => 'python' }) }

      it 'returns the configured language' do
        expect(plugin.serverless_language).to eq('python')
      end
    end

    context "when settings.yml has serverless_language: ''" do
      before { plugin.instance_variable_set(:@config, { 'serverless_language' => '' }) }

      it 'returns nil so the inferred extension wins' do
        expect(plugin.serverless_language).to be_nil
      end
    end

    context 'when settings.yml omits serverless_language' do
      before { plugin.instance_variable_set(:@config, {}) }

      it 'returns nil' do
        expect(plugin.serverless_language).to be_nil
      end
    end
  end

  describe '#reload!' do
    it 'raises a readable InvalidConfig when settings.yml is not valid YAML' do
      Dir.mktmpdir('trmnlp-plugin-') do |dir|
        FileUtils.mkdir_p(File.join(dir, 'src'))
        File.write(File.join(dir, 'src', 'settings.yml'), 'name: [unclosed')
        bad_paths = TRMNLP::Paths.new(dir)

        expect { described_class.new(bad_paths, TRMNLP::Config::Project.new(bad_paths)) }
          .to raise_error(TRMNLP::InvalidConfig, /settings\.yml is not valid YAML/)
      end
    end
  end
end
