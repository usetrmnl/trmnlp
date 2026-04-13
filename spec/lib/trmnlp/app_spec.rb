require 'spec_helper'
require 'trmnlp/app'
require 'rack/test'

RSpec.describe TRMNLP::App do
  include Rack::Test::Methods

  let(:fixture_dir) { File.join(__dir__, '../../fixtures') }
  let(:context) { TRMNLP::Context.new(fixture_dir) }

  # Context uses puts/print for logging; keep test output clean.
  before { allow($stdout).to receive(:write) }

  def app
    TRMNLP::App.set(:context, context)
    TRMNLP::App.set(:host_authorization, { allow_if: ->(_env) { true } })
    TRMNLP::App.new
  end

  describe 'GET /' do
    it 'redirects to /full' do
      get '/'
      expect(last_response).to be_redirect
      expect(last_response.location).to end_with('/full')
    end
  end

  describe 'GET /full' do
    it 'returns 200 with the preview shell' do
      get '/full'
      expect(last_response).to be_ok
      expect(last_response.body).to include('TRMNL Preview')
      expect(last_response.body).to include('active')
    end
  end

  describe 'GET /data' do
    it 'returns JSON user_data' do
      get '/data'
      expect(last_response).to be_ok
      expect(last_response.content_type).to include('application/json')

      data = JSON.parse(last_response.body)
      expect(data).to have_key('trmnl')
      expect(data['trmnl']).to have_key('user')
    end
  end

  describe 'GET /render/full.html' do
    it 'returns rendered Liquid inside the TRMNL HTML shell' do
      get '/render/full.html'
      expect(last_response).to be_ok
      expect(last_response.body).to include('environment trmnl')
      expect(last_response.body).to include('hello from fixture')
    end
  end

  describe 'POST /webhook' do
    it 'accepts JSON and returns OK' do
      post '/webhook', '{"key": "value"}', 'CONTENT_TYPE' => 'application/json'
      expect(last_response).to be_ok
      expect(last_response.body).to eq('OK')
    end
  end

  describe 'GET /poll' do
    it 'triggers poll_data and redirects back' do
      allow(context).to receive(:poll_data)
      get '/poll'
      expect(last_response).to be_redirect
      expect(context).to have_received(:poll_data).at_least(:twice)
    end
  end
end
