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

  describe 'GET /poll' do
    it 'triggers a poll and redirects back' do
      get '/poll', {}, { 'HTTP_REFERER' => '/full' }

      expect(last_response.status).to eq(302)
      expect(context.poller).to have_received(:poll_data).at_least(:once)
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
