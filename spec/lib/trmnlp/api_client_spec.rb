# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/api_client'
require 'faraday/adapter/test'

RSpec.describe TRMNLP::APIClient do
  subject(:client) { described_class.new(config) }

  let(:stubs) { Faraday::Adapter::Test::Stubs.new }
  let(:faraday_conn) do
    Faraday.new(headers: { 'Authorization' => 'Bearer user_test' }) do |f|
      f.request :multipart
      f.adapter :test, stubs
    end
  end
  let(:config) { double('config') }

  before { allow(client).to receive(:conn).and_return(faraday_conn) }

  describe '#get_me' do
    it 'returns the data key from a 200 response' do
      stubs.get('me') { [200, {}, JSON.generate('data' => { 'name' => 'Bluey', 'email' => 'b@example.com' })] }
      expect(client.get_me).to eq('name' => 'Bluey', 'email' => 'b@example.com')
    end

    it 'raises on a non-200 response' do
      stubs.get('me') { [401, {}, '{"error":"unauthorized"}'] }
      expect { client.get_me }.to raise_error(TRMNLP::Error, /401/)
    end
  end

  describe '#get_plugin_settings' do
    it 'returns the data key from a 200 response' do
      stubs.get('plugin_settings') do
        [200, {}, JSON.generate('data' => [{ 'id' => 1, 'plugin_id' => 37, 'name' => 'Demo' }])]
      end

      expect(client.get_plugin_settings).to eq([{ 'id' => 1, 'plugin_id' => 37, 'name' => 'Demo' }])
    end

    it 'raises on a non-200 response' do
      stubs.get('plugin_settings') { [500, {}, '{"error":"server down"}'] }
      expect { client.get_plugin_settings }.to raise_error(TRMNLP::Error, /500/)
    end
  end

  describe '#post_plugin_setting' do
    it 'returns the parsed body on 200' do
      stubs.post('plugin_settings') do
        [200, {}, JSON.generate('data' => { 'id' => 99 })]
      end

      expect(client.post_plugin_setting(name: 'X', plugin_id: 37)).to eq('data' => { 'id' => 99 })
    end
  end

  describe '#delete_plugin_setting' do
    it 'returns true on 204' do
      stubs.delete('plugin_settings/42') { [204, {}, ''] }
      expect(client.delete_plugin_setting(42)).to be(true)
    end

    it 'raises on anything else' do
      stubs.delete('plugin_settings/42') { [404, {}, '{"error":"not found"}'] }
      expect { client.delete_plugin_setting(42) }.to raise_error(TRMNLP::Error, /404/)
    end
  end
end
