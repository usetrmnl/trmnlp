# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe TRMNLP::Config::Project do
  subject(:project) { described_class.new(paths) }

  let(:root_dir) { File.join(__dir__, '../../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }

  describe '#custom_fields' do
    context 'with overrides' do
      subject(:project) { described_class.new(paths, overrides:) }

      let(:overrides) { { 'custom_fields' => { 'character_name' => 'Bingo' } } }

      it 'replaces those keys of .trmnlp.yml, so a test sees none of its development values' do
        expect(project.custom_fields).to eq('character_name' => 'Bingo')
      end

      context 'when they name another key' do
        let(:overrides) { { 'variables' => { 'greeting' => 'hi' } } }

        it 'keeps the keys they do not name' do
          expect(project.custom_fields).to include('character_name' => 'Bluey')
        end
      end

      it 'keeps them across a reload' do
        project.reload!

        expect(project.custom_fields).to include('character_name' => 'Bingo')
      end
    end

    it 'transforms scalar values to strings' do
      expect(project.custom_fields).to include('character_name' => 'Bluey', 'character_age' => '7')
    end

    it 'preserves arrays as arrays (multi-select fields, issue #80)' do
      expect(project.custom_fields).to include('favorite_episodes' => %w[Sleepytime Camping])
    end

    it 'stringifies elements within arrays for parity with the hosted service' do
      expect(project.custom_fields).to include('rolls' => %w[1 2])
    end

    it 'recursively stringifies nested array and hash values' do
      config = {
        'custom_fields' => {
          'nested' => {
            'items' => [1, { 'value' => 2 }, [3, 4]],
            'enabled' => true
          }
        }
      }
      project.instance_variable_set(:@config, config)

      expect(project.custom_fields).to include(
        'nested' => {
          'items' => ['1', { 'value' => '2' }, %w[3 4]],
          'enabled' => 'true'
        }
      )
    end

    context 'when there is no .trmnlp yaml file in the path' do
      let(:root_dir) { 'not-a-valid-path' }

      it 'returns an empty hash' do
        expect(project.custom_fields).to eq({})
      end
    end
  end

  describe '#with_custom_fields' do
    it 'renders custom field values' do
      expect(project.with_custom_fields('in {{ city }}', values: { 'city' => 'Perth' })).to eq('in Perth')
    end

    it 'merges extra variables into the render context' do
      rendered = project.with_custom_fields('Bearer {{ oauth_access_token }}',
                                            values: {}, extra_variables: { 'oauth_access_token' => 'AT' })
      expect(rendered).to eq('Bearer AT')
    end
  end

  describe '#user_filter_modules' do
    it 'loads each module listed under custom_filters' do
      Dir.mktmpdir('trmnlp-project-') do |dir|
        File.write(File.join(dir, 'filters.rb'), "module TrmnlpSpecShoutFilter\n  def shout(input) = input\nend\n")
        File.write(File.join(dir, '.trmnlp.yml'), "custom_filters:\n  TrmnlpSpecShoutFilter: filters.rb\n")

        expect(described_class.new(TRMNLP::Paths.new(dir)).user_filter_modules.map(&:name))
          .to eq(%w[TrmnlpSpecShoutFilter])
      end
    end
  end

  describe '#serverless_daemon_api_key' do
    let(:root_dir) { 'not-a-valid-path' }

    it 'reads from $TRMNL_SERVERLESS_DAEMON_API_KEY when set' do
      stub_const('ENV', ENV.to_h.merge('TRMNL_SERVERLESS_DAEMON_API_KEY' => 'from-env'))
      expect(project.serverless_daemon_api_key).to eq('from-env')
    end

    it 'returns nil when neither env nor config provides one' do
      stub_const('ENV', ENV.to_h.except('TRMNL_SERVERLESS_DAEMON_API_KEY'))
      expect(project.serverless_daemon_api_key).to be_nil
    end
  end

  describe '#transform_runtime' do
    it 'defaults to enabled when .trmnlp.yml does not configure it' do
      expect(project.transform_runtime).to eq('enabled')
    end

    context 'when .trmnlp.yml opts out' do
      before { project.instance_variable_set(:@config, { 'transform_runtime' => 'disabled' }) }

      it 'returns the configured value' do
        expect(project.transform_runtime).to eq('disabled')
      end
    end
  end

  describe '#reload!' do
    it 'raises a readable InvalidConfig when .trmnlp.yml is not valid YAML' do
      Dir.mktmpdir('trmnlp-project-') do |dir|
        File.write(File.join(dir, '.trmnlp.yml'), 'watch: [unclosed')

        expect { described_class.new(TRMNLP::Paths.new(dir)) }
          .to raise_error(TRMNLP::InvalidConfig, /\.trmnlp\.yml is not valid YAML/)
      end
    end
  end

  describe '#watch_paths' do
    let(:root_dir) { Dir.mktmpdir('trmnlp-watch-') }

    after { FileUtils.remove_entry(root_dir) }

    def configure(config)
      File.write(File.join(root_dir, '.trmnlp.yml'), config.to_yaml)
      project.reload!
    end

    it 'watches the local files and folders that asset overrides point at, so serve redraws when they change' do
      configure('watch' => ['src'], 'asset_overrides' => { 'https://example.test/app.js' => 'dist/app.js',
                                                           'https://example.test/icons/' => 'icons' })
      expect(project.watch_paths.map(&:to_s)).to eq(%w[src dist/app.js icons].map { File.join(root_dir, it) })
    end

    it 'does not watch an override that points at another URL' do
      configure('asset_overrides' => { 'https://example.test/app.js' => 'https://mirror.test/app.js' })
      expect(project.watch_paths).to be_empty
    end
  end

  describe '#asset_overrides' do
    let(:root_dir) { Dir.mktmpdir('trmnlp-overrides-') }

    after { FileUtils.remove_entry(root_dir) }

    def configure(mapping)
      File.write(File.join(root_dir, '.trmnlp.yml'), { 'asset_overrides' => mapping }.to_yaml)
      project.reload!
    end

    it 'resolves a file relative to the project' do
      File.write(File.join(root_dir, 'logo.svg'), '<svg/>')
      configure('https://example.test/logo.svg' => 'logo.svg')
      expect(project.asset_overrides).to eq('https://example.test/logo.svg' => File.join(root_dir, 'logo.svg'))
    end

    it 'resolves a folder for a prefix key' do
      FileUtils.mkdir_p(File.join(root_dir, 'images'))
      configure('https://example.test/images/' => 'images')
      expect(project.asset_overrides).to eq('https://example.test/images/' => File.join(root_dir, 'images'))
    end

    it 'keeps a URL target' do
      configure('https://example.test/logo.svg' => 'https://mirror.test/logo.svg')
      expect(project.asset_overrides).to eq('https://example.test/logo.svg' => 'https://mirror.test/logo.svg')
    end

    it 'rejects a wildcard key' do
      configure('https://example.test/*.svg' => 'https://mirror.test/logo.svg')
      expect { project.asset_overrides }.to raise_error(TRMNLP::InvalidConfig, /literal URL/)
    end

    it 'rejects a missing local file with the URL and path' do
      configure('https://example.test/logo.svg' => 'missing.svg')
      expect { project.asset_overrides }.to raise_error(TRMNLP::InvalidConfig, %r{example.test/logo.svg.*missing.svg})
    end

    it 'requires a trailing slash for folder keys' do
      FileUtils.mkdir_p(File.join(root_dir, 'images'))
      configure('https://example.test/images' => 'images')
      expect { project.asset_overrides }.to raise_error(TRMNLP::InvalidConfig, %r{trailing /|end in /|prefix})
    end

    it 'rejects a file as a prefix target' do
      File.write(File.join(root_dir, 'logo.svg'), '<svg/>')
      configure('https://example.test/images/' => 'logo.svg')
      expect { project.asset_overrides }.to raise_error(TRMNLP::InvalidConfig, /URL prefix needs a local folder/)
    end
  end
end
