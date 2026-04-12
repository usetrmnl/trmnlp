require 'spec_helper'

RSpec.describe TRMNLP::Config::App do
  let(:fixture_dir) { File.join(__dir__, '../../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(fixture_dir) }

  subject(:app_config) { described_class.new(paths) }

  describe '#api_key' do
    context 'when TRMNL_API_KEY env var is set' do
      around do |example|
        original = ENV['TRMNL_API_KEY']
        ENV['TRMNL_API_KEY'] = 'user_env_key_abc'
        example.run
        ENV['TRMNL_API_KEY'] = original
      end

      it 'returns the env var value' do
        expect(app_config.api_key).to eq('user_env_key_abc')
      end
    end

    context 'when TRMNL_API_KEY env var is not set' do
      around do |example|
        original = ENV.delete('TRMNL_API_KEY')
        example.run
        ENV['TRMNL_API_KEY'] = original if original
      end

      it 'falls back to config file value (nil for fixture)' do
        expect(app_config.api_key).to be_nil
      end
    end
  end

  describe '#logged_in?' do
    context 'when api_key is present' do
      before { allow(app_config).to receive(:api_key).and_return('user_some_key') }

      it 'returns true' do
        expect(app_config.logged_in?).to be true
      end
    end

    context 'when api_key is nil' do
      before { allow(app_config).to receive(:api_key).and_return(nil) }

      it 'returns falsey' do
        expect(app_config.logged_in?).to be_falsey
      end
    end

    context 'when api_key is empty' do
      before { allow(app_config).to receive(:api_key).and_return('') }

      it 'returns false' do
        expect(app_config.logged_in?).to be false
      end
    end
  end

  describe '#logged_out?' do
    it 'is the inverse of logged_in?' do
      allow(app_config).to receive(:api_key).and_return('user_key')
      expect(app_config.logged_out?).to be false

      allow(app_config).to receive(:api_key).and_return(nil)
      expect(app_config.logged_out?).to be true
    end
  end

  describe '#base_uri' do
    it 'defaults to https://trmnl.com' do
      expect(app_config.base_uri.to_s).to eq('https://trmnl.com')
    end
  end

  describe '#api_uri' do
    it 'is base_uri + /api' do
      expect(app_config.api_uri.to_s).to eq('https://trmnl.com/api')
    end
  end

  describe '#edit_plugin_settings_uri' do
    it 'builds the edit URL with the given ID' do
      uri = app_config.edit_plugin_settings_uri(42)
      expect(uri.to_s).to eq('https://trmnl.com/plugin_settings/42/edit')
    end
  end
end
