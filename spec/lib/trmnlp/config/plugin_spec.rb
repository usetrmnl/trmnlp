require 'spec_helper'

RSpec.describe TRMNLP::Config::Plugin do
  let(:fixture_dir) { File.join(__dir__, '../../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(fixture_dir) }
  let(:project) { TRMNLP::Config::Project.new(paths) }

  subject(:plugin) { described_class.new(paths, project) }

  describe '#strategy' do
    it 'returns the strategy from settings.yml' do
      expect(plugin.strategy).to eq('static')
    end
  end

  describe '#polling?' do
    it 'returns false when strategy is static' do
      expect(plugin.polling?).to be false
    end
  end

  describe '#webhook?' do
    it 'returns false when strategy is static' do
      expect(plugin.webhook?).to be false
    end
  end

  describe '#static?' do
    it 'returns true when strategy is static' do
      expect(plugin.static?).to be true
    end
  end

  describe '#dark_mode' do
    it 'returns the configured dark_mode value' do
      expect(plugin.dark_mode).to eq('no')
    end

    context 'when dark_mode is not configured' do
      before { allow(plugin).to receive(:strategy).and_return(nil) }

      it 'defaults to no' do
        tmp = Dir.mktmpdir
        empty_settings = File.join(tmp, 'src', 'settings.yml')
        FileUtils.mkdir_p(File.dirname(empty_settings))
        File.write(empty_settings, "strategy: polling\n")
        File.write(File.join(tmp, '.trmnlp.yml'), '')

        tmp_paths = TRMNLP::Paths.new(tmp)
        tmp_project = TRMNLP::Config::Project.new(tmp_paths)
        tmp_plugin = described_class.new(tmp_paths, tmp_project)

        expect(tmp_plugin.dark_mode).to eq('no')

        FileUtils.rm_rf(tmp)
      end
    end
  end

  describe '#static_data' do
    it 'parses JSON from settings.yml' do
      expect(plugin.static_data).to eq({ 'message' => 'hello from fixture' })
    end

    it 'raises TRMNLP::Error on invalid JSON' do
      allow(plugin).to receive(:static_data).and_call_original
      # Temporarily override to test invalid JSON
      plugin.instance_variable_get(:@config)['static_data'] = 'not valid json {'
      expect { plugin.static_data }.to raise_error(TRMNLP::Error, /invalid JSON/)
    end
  end

  describe '#polling_urls' do
    it 'returns empty array when not configured' do
      expect(plugin.polling_urls).to eq([])
    end

    context 'with a single polling URL' do
      before do
        plugin.instance_variable_get(:@config)['polling_url'] = 'https://api.example.com/data'
      end

      it 'returns the URL in an array' do
        expect(plugin.polling_urls).to eq(['https://api.example.com/data'])
      end
    end

    context 'with multiple polling URLs (newline-separated)' do
      before do
        plugin.instance_variable_get(:@config)['polling_url'] = "https://api.example.com/a\nhttps://api.example.com/b"
      end

      it 'returns all URLs' do
        expect(plugin.polling_urls).to eq(['https://api.example.com/a', 'https://api.example.com/b'])
      end
    end
  end

  describe '#polling_headers' do
    it 'returns empty hash when not configured' do
      expect(plugin.polling_headers).to eq({})
    end

    context 'with key=value&key=value format' do
      before do
        plugin.instance_variable_get(:@config)['polling_headers'] = 'Authorization=Bearer%20token123&Accept=application/json'
      end

      it 'parses into a hash with unescaped values' do
        headers = plugin.polling_headers
        expect(headers['Authorization']).to eq('Bearer token123')
        expect(headers['Accept']).to eq('application/json')
      end
    end
  end

  describe '#polling_verb' do
    it 'defaults to GET' do
      expect(plugin.polling_verb).to eq('GET')
    end
  end

  describe '#reload!' do
    it 'reloads config from disk' do
      expect(plugin.strategy).to eq('static')
      # This verifies reload! can be called without error
      plugin.reload!
      expect(plugin.strategy).to eq('static')
    end
  end
end
