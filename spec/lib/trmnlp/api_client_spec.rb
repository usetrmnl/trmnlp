require 'spec_helper'
require 'trmnlp/api_client'

RSpec.describe TRMNLP::APIClient do
  let(:fixture_dir) { File.join(__dir__, '../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(fixture_dir) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:api_client) { described_class.new(config) }
  let(:api_base) { 'https://trmnl.com/api' }

  before do
    allow(config.app).to receive(:api_key).and_return('user_test_key_123')
  end

  describe '#get_me' do
    it 'returns parsed user data on 200' do
      stub_request(:get, "#{api_base}/me")
        .to_return(status: 200, body: '{"data": {"name": "Test", "email": "test@example.com"}}',
                   headers: { 'Content-Type' => 'application/json' })

      result = api_client.get_me
      expect(result).to eq({ 'name' => 'Test', 'email' => 'test@example.com' })
    end

    it 'raises TRMNLP::Error on non-200' do
      stub_request(:get, "#{api_base}/me")
        .to_return(status: 401, body: 'Unauthorized')

      expect { api_client.get_me }.to raise_error(TRMNLP::Error, /failed to fetch user info/)
    end
  end

  describe '#get_plugin_settings' do
    it 'returns parsed plugin settings list on 200' do
      body = '{"data": [{"id": 1, "name": "My Plugin"}]}'
      stub_request(:get, "#{api_base}/plugin_settings")
        .to_return(status: 200, body: body, headers: { 'Content-Type' => 'application/json' })

      result = api_client.get_plugin_settings
      expect(result).to eq([{ 'id' => 1, 'name' => 'My Plugin' }])
    end

    it 'raises TRMNLP::Error on non-200' do
      stub_request(:get, "#{api_base}/plugin_settings")
        .to_return(status: 500, body: 'Server Error')

      expect { api_client.get_plugin_settings }.to raise_error(TRMNLP::Error)
    end
  end

  describe '#get_plugin_setting_archive' do
    it 'returns a tempfile with ZIP content on 200' do
      zip_content = 'PK_fake_zip_data'
      stub_request(:get, "#{api_base}/plugin_settings/42/archive")
        .to_return(status: 200, body: zip_content)

      tempfile = api_client.get_plugin_setting_archive(42)
      expect(tempfile).to be_a(Tempfile)
      expect(tempfile.read).to eq(zip_content)
      tempfile.close
      tempfile.unlink
    end

    it 'raises TRMNLP::Error on non-200' do
      stub_request(:get, "#{api_base}/plugin_settings/42/archive")
        .to_return(status: 404, body: 'Not Found')

      expect { api_client.get_plugin_setting_archive(42) }.to raise_error(TRMNLP::Error)
    end
  end

  describe '#post_plugin_setting_archive' do
    it 'uploads a multipart zip and returns parsed response on 200' do
      stub_request(:post, "#{api_base}/plugin_settings/42/archive")
        .to_return(status: 200, body: '{"data": {"settings_yaml": "strategy: static"}}',
                   headers: { 'Content-Type' => 'application/json' })

      tmpfile = Tempfile.new(['test', '.zip'])
      tmpfile.write('fake zip')
      tmpfile.close

      result = api_client.post_plugin_setting_archive(42, tmpfile.path)
      expect(result).to eq({ 'data' => { 'settings_yaml' => 'strategy: static' } })

      tmpfile.unlink
    end

    it 'raises TRMNLP::Error on non-200' do
      stub_request(:post, "#{api_base}/plugin_settings/42/archive")
        .to_return(status: 422, body: 'Unprocessable')

      tmpfile = Tempfile.new(['test', '.zip'])
      tmpfile.write('fake zip')
      tmpfile.close

      expect { api_client.post_plugin_setting_archive(42, tmpfile.path) }.to raise_error(TRMNLP::Error)

      tmpfile.unlink
    end
  end

  describe '#post_plugin_setting' do
    it 'sends JSON and returns parsed response on 200' do
      stub_request(:post, "#{api_base}/plugin_settings")
        .with(body: '{"name":"New Plugin","plugin_id":37}')
        .to_return(status: 200, body: '{"data": {"id": 99}}',
                   headers: { 'Content-Type' => 'application/json' })

      result = api_client.post_plugin_setting(name: 'New Plugin', plugin_id: 37)
      expect(result).to eq({ 'data' => { 'id' => 99 } })
    end

    it 'raises TRMNLP::Error on non-200' do
      stub_request(:post, "#{api_base}/plugin_settings")
        .to_return(status: 400, body: 'Bad Request')

      expect { api_client.post_plugin_setting(name: 'Bad') }.to raise_error(TRMNLP::Error)
    end
  end

  describe '#delete_plugin_setting' do
    it 'returns true on 204' do
      stub_request(:delete, "#{api_base}/plugin_settings/42")
        .to_return(status: 204, body: '')

      expect(api_client.delete_plugin_setting(42)).to be true
    end

    it 'raises TRMNLP::Error on non-204' do
      stub_request(:delete, "#{api_base}/plugin_settings/42")
        .to_return(status: 403, body: 'Forbidden')

      expect { api_client.delete_plugin_setting(42) }.to raise_error(TRMNLP::Error)
    end
  end
end
