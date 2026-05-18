# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe TRMNLP::Config::App do
  subject(:app_config) { described_class.new(paths) }

  let(:tmp_root) { Dir.mktmpdir('trmnlp-config-app-') }
  let(:paths) do
    instance_double(
      TRMNLP::Paths,
      app_config: Pathname.new(File.join(tmp_root, 'config.yml')),
      app_config_dir: Pathname.new(tmp_root)
    )
  end

  after { FileUtils.rm_rf(tmp_root) }

  describe '#api_key' do
    context 'when TRMNL_API_KEY is set in the environment' do
      before { stub_const('ENV', ENV.to_hash.merge('TRMNL_API_KEY' => 'user_env_key')) }

      it 'returns the environment value' do
        expect(app_config.api_key).to eq('user_env_key')
      end

      it 'takes precedence over the saved config file' do
        File.write(paths.app_config, YAML.dump('api_key' => 'user_saved_key'))
        expect(described_class.new(paths).api_key).to eq('user_env_key')
      end
    end

    context 'without TRMNL_API_KEY in the environment' do
      before { stub_const('ENV', ENV.to_hash.merge('TRMNL_API_KEY' => nil)) }

      it 'returns the saved config value when present' do
        File.write(paths.app_config, YAML.dump('api_key' => 'user_from_disk'))
        expect(described_class.new(paths).api_key).to eq('user_from_disk')
      end

      it 'returns nil when nothing is saved' do
        expect(app_config.api_key).to be_nil
      end
    end
  end

  describe '#logged_in?' do
    it 'is false when api_key is nil' do
      expect(app_config).not_to be_logged_in
    end

    it 'is true when an api_key is set' do
      app_config.api_key = 'user_xyz'
      expect(app_config).to be_logged_in
    end
  end

  describe '#save' do
    it 'persists the api_key to disk' do
      app_config.api_key = 'user_saved'
      app_config.save

      expect(YAML.safe_load(paths.app_config.read)).to include('api_key' => 'user_saved')
    end
  end

  describe '#base_uri' do
    it 'defaults to trmnl.com' do
      expect(app_config.base_uri.to_s).to eq('https://trmnl.com')
    end

    context 'when a custom base_url is saved' do
      before { File.write(paths.app_config, YAML.dump('base_url' => 'https://staging.trmnl.com')) }

      it 'honours the override' do
        expect(described_class.new(paths).base_uri.to_s).to eq('https://staging.trmnl.com')
      end
    end
  end

  describe '#api_uri' do
    it 'derives from base_uri' do
      expect(app_config.api_uri.to_s).to eq('https://trmnl.com/api')
    end
  end

  describe '#account_uri' do
    it 'derives from base_uri' do
      expect(app_config.account_uri.to_s).to eq('https://trmnl.com/account')
    end
  end

  describe '#edit_plugin_settings_uri' do
    it 'builds the edit URL for a given id' do
      expect(app_config.edit_plugin_settings_uri(42).to_s).to eq('https://trmnl.com/plugin_settings/42/edit')
    end
  end
end
