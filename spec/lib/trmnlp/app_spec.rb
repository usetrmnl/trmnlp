# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'

# `app.rb` is loaded lazily by commands/serve.rb. Load it here so we can
# spec the routes without booting the full Sinatra reloader.
require 'trmnlp/app'
require 'trmnlp/browser_pool'

RSpec.describe TRMNLP::App do
  include Rack::Test::Methods

  let(:fixtures_root) { File.expand_path('../../fixtures', __dir__) }
  let(:context) do
    ctx = TRMNLP::Context.new(fixtures_root)
    # Avoid hitting the real network or filewatcher loop during specs.
    allow(ctx.poller).to receive(:poll_data)
    allow(ctx.config.project).to receive(:live_render?).and_return(false)
    ctx
  end

  before do
    # Sinatra caches one prototype instance class-wide; without reset
    # the let(:context) from the first example would be re-used by the
    # rest, masking call assertions.
    described_class.instance_variable_set(:@prototype, nil)
    described_class.set(:context, context)
    described_class.set(:browser_pool, instance_double(TRMNLP::BrowserPool))
    # Sinatra 4 ships host_authorization on by default; the test client
    # sends Host: example.org which isn't on the allow-list. Permit all
    # hosts in specs.
    described_class.set(:host_authorization, permitted_hosts: [])
  end

  def app = described_class

  describe 'GET /data' do
    it 'returns user_data as pretty JSON with default device dims' do
      get '/data'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body.dig('trmnl', 'device', 'width')).to eq(800)
      expect(body.dig('trmnl', 'device', 'height')).to eq(480)
    end

    it 'honors width and height query params (issue #94)' do
      get '/data?width=400&height=240'

      body = JSON.parse(last_response.body)
      expect(body.dig('trmnl', 'device', 'width')).to eq(400)
      expect(body.dig('trmnl', 'device', 'height')).to eq(240)
    end
  end

  describe 'GET /' do
    it 'redirects to /full' do
      get '/'

      expect(last_response.status).to eq(302)
      expect(last_response.headers['Location']).to eq('http://example.org/full')
    end
  end

  describe 'GET /:view' do
    it 'renders an index page for every screen view' do
      views = %w[full half_horizontal half_vertical quadrant]
      statuses = views.to_h do |view|
        get "/#{view}"
        [view, last_response.status]
      end

      expect(statuses).to eq(views.to_h { |view| [view, 200] })
    end

    it 'renders the TRMNL preview chrome' do
      get '/full'

      expect(last_response.body).to include('TRMNL Preview')
    end

    it 'shows the merge-variable payload size' do
      get '/full'

      expect(last_response.body).to match(/Payload: \d/)
    end

    it 'HTML-escapes the transform error to prevent script injection' do
      allow(context.transform_pipeline).to receive(:error).and_return('<script>alert(1)</script>')

      get '/full'

      expect(last_response.body).to include('&lt;script&gt;alert(1)&lt;/script&gt;')
    end
  end

  describe 'GET /:view oauth banner' do
    it 'invites connection when configured but not connected' do
      allow(context.oauth_session).to receive_messages(configured?: true, connected?: false)

      get '/full'

      expect(last_response.body).to include('/oauth/connect')
    end

    it 'offers disconnect when connected' do
      allow(context.oauth_session).to receive_messages(configured?: true, connected?: true)

      get '/full'

      expect(last_response.body).to include('/oauth/disconnect')
    end

    it 'shows no oauth banner when unconfigured' do
      allow(context.oauth_session).to receive(:configured?).and_return(false)

      get '/full'

      expect(last_response.body).not_to include('/oauth/connect')
    end
  end

  describe 'GET /:view payload-size badge (#67)' do
    it 'marks a payload under 75 KB green' do
      allow(context.user_data_assembler).to receive(:call).and_return({ 'k' => 'small' })

      get '/full'

      expect(last_response.body).to include('payload-size payload-size--ok')
    end

    it 'marks a payload between 75 and 100 KB yellow' do
      allow(context.user_data_assembler).to receive(:call).and_return({ 'k' => 'a' * 90_000 })

      get '/full'

      expect(last_response.body).to include('payload-size payload-size--warn')
    end

    it 'marks a payload at or above 100 KB red' do
      allow(context.user_data_assembler).to receive(:call).and_return({ 'k' => 'a' * 110_000 })

      get '/full'

      expect(last_response.body).to include('payload-size payload-size--over')
    end
  end

  describe 'GET /poll' do
    it 'triggers a poll and redirects back' do
      get '/poll', {}, { 'HTTP_REFERER' => '/full' }

      expect(last_response.status).to eq(302)
      expect(context.poller).to have_received(:poll_data).at_least(:once)
    end
  end

  describe 'GET /oauth/connect' do
    context 'when oauth is configured' do
      before do
        allow(context.oauth_session).to receive_messages(configured?: true, pkce?: false)
        allow(context.oauth_session).to receive(:authorize_url)
          .and_return('https://provider.test/authorize?state=x')
      end

      it 'redirects to the provider authorize url' do
        get '/oauth/connect'

        expect(last_response.headers['Location']).to eq('https://provider.test/authorize?state=x')
      end

      it 'derives the callback redirect_uri from the request' do
        get '/oauth/connect'

        expect(context.oauth_session).to have_received(:authorize_url)
          .with(hash_including(redirect_uri: 'http://example.org/oauth/callback'))
      end
    end

    context 'with a PKCE provider' do
      before do
        allow(context.oauth_session).to receive_messages(configured?: true, pkce?: true)
        allow(context.oauth_session).to receive(:authorize_url).and_return('https://provider.test/authorize')
      end

      it 'sends a code challenge' do
        get '/oauth/connect'

        expect(context.oauth_session).to have_received(:authorize_url)
          .with(hash_including(code_challenge: an_instance_of(String)))
      end
    end

    context 'when oauth is not configured' do
      before { allow(context.oauth_session).to receive(:configured?).and_return(false) }

      it 'responds 400' do
        get '/oauth/connect'

        expect(last_response.status).to eq(400)
      end
    end
  end

  describe 'GET /oauth/callback' do
    before do
      allow(context.oauth_session).to receive_messages(configured?: true, pkce?: false, complete: nil)
      allow(context.oauth_session).to receive(:authorize_url) do |state:, **|
        @state = state
        'https://provider.test/authorize'
      end
    end

    it 'exchanges a valid code and redirects home' do
      get '/oauth/connect'
      get "/oauth/callback?code=abc&state=#{@state}"

      expect(last_response.headers['Location']).to eq('http://example.org/')
    end

    it 'passes the authorization code to the session' do
      get '/oauth/connect'
      get "/oauth/callback?code=abc&state=#{@state}"

      expect(context.oauth_session).to have_received(:complete).with(hash_including(code: 'abc'))
    end

    it 'rejects a mismatched state' do
      get '/oauth/callback?code=abc&state=forged'

      expect(last_response.status).to eq(400)
    end

    it 'surfaces a provider error' do
      get '/oauth/callback?error=access_denied'

      expect(last_response.status).to eq(400)
    end
  end

  describe 'GET /oauth/disconnect' do
    before { allow(context.oauth_session).to receive(:disconnect) }

    it 'clears the connection and redirects home' do
      get '/oauth/disconnect'

      expect(context.oauth_session).to have_received(:disconnect)
    end
  end

  describe 'POST /webhook' do
    let(:payload) { '{"items":[1,2,3]}' }

    before { allow(context.poller).to receive(:put_webhook) }

    it 'forwards the body to the poller and returns OK' do
      post '/webhook', payload, { 'CONTENT_TYPE' => 'application/json' }

      expect(last_response.status).to eq(200)
      expect(last_response.body).to eq('OK')
      expect(context.poller).to have_received(:put_webhook).with(payload)
    end
  end
end
