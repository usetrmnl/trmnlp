# frozen_string_literal: true

require 'spec_helper'
require 'rack/test'
require 'net/http'
require 'trmnlp/testing/asset_cache'

# `app.rb` is loaded lazily by commands/serve.rb. Load it here so we can
# spec the routes without booting the full Sinatra reloader.
require 'trmnlp/app'
require 'trmnlp/browser_pool'
require 'trmnlp/firefox_driver'

require 'fileutils'
require 'tmpdir'
require 'yaml'

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
    described_class.set(:asset_cache, TRMNLP::Testing::AssetCache.new(dir: Dir.mktmpdir('trmnlp-assets-')))
    # Sinatra 4 ships host_authorization on by default; the test client
    # sends Host: example.org which isn't on the allow-list. Permit all
    # hosts in specs.
    described_class.set(:host_authorization, permitted_hosts: [])
  end

  def app = described_class

  describe 'GET /render/:view.png with a palette TRMNL does not have' do
    before do
      allow(TRMNLP::Testing::DeviceModels).to receive(:palettes).and_return([{ 'id' => 'bw', 'grays' => 2 }])
      get '/render/full.png?palette=nope'
    end

    it 'refuses the render' do
      expect(last_response.status).to eq(400)
    end

    it 'names the palettes TRMNL has' do
      expect(last_response.body).to eq('Unknown palette "nope"; known: bw')
    end
  end

  describe 'GET /render/:view.html with asset overrides' do
    let(:project_dir) { Dir.mktmpdir('trmnlp-preview-assets-') }
    let(:context) { TRMNLP::Context.new(project_dir).tap { allow(it.poller).to receive(:poll_data) } }
    let(:source) { 'https://assets.example.test/logo.svg' }
    let(:cache) { TRMNLP::Testing::AssetCache.new(dir: File.join(project_dir, 'cache')).start }

    before do
      FileUtils.mkdir_p(File.join(project_dir, 'src'))
      File.write(File.join(project_dir, '.trmnlp.yml'), { 'asset_overrides' => { source => 'logo.svg' } }.to_yaml)
      File.write(File.join(project_dir, 'logo.svg'), '<svg>first</svg>')
      File.write(File.join(project_dir, 'src', 'settings.yml'), "framework_version: '#{TRMNLP::FrameworkVersion.latest}'\n")
      File.write(File.join(project_dir, 'src', 'full.liquid'), %(<img src="#{source}">))
      context.config.project.reload!
      WebMock.disable_net_connect!(allow_localhost: true)
      described_class.set(:asset_cache, cache)
    end

    after do
      cache.stop
      FileUtils.remove_entry(project_dir)
    end

    def overridden_path
      get '/render/full.html'
      last_response.body[/<img src="([^"]+)/, 1]
    end

    it 'points the live preview at its own address, so a browser outside the machine or container reaches it' do
      expect(overridden_path).to start_with('/overrides/')
    end

    it 'serves the override from its own address' do
      get overridden_path
      expect(last_response).to have_attributes(body: '<svg>first</svg>', content_type: 'image/svg+xml')
    end

    it 'serves a changed local file on the next request' do
      path = overridden_path
      File.write(File.join(project_dir, 'logo.svg'), '<svg>changed</svg>')
      get path
      expect(last_response.body).to eq('<svg>changed</svg>')
    end

    it 'leaves the Framework links of the live preview alone' do
      File.write(File.join(project_dir, 'src', 'full.liquid'),
                 %(<img src="#{source}"><link href="https://trmnl.com/css/3.4.2/plugins.css">))
      get '/render/full.html'
      expect(last_response.body).to include('href="https://trmnl.com/css/3.4.2/plugins.css"')
    end
  end

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

    it 'links to the issue tracker for bug reports' do
      allow(context.oauth_session).to receive_messages(configured?: true, connected?: false)

      get '/full'

      expect(last_response.body).to include('github.com/usetrmnl/trmnlp/issues')
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

  describe 'GET /render/:view.html on a device the Framework scales' do
    let(:project_dir) { Dir.mktmpdir('trmnlp-live-preview-') }
    let(:context) { TRMNLP::Context.new(project_dir).tap { allow(it.poller).to receive(:poll_data) } }
    let(:pool) { TRMNLP::BrowserPool.new(driver_factory: TRMNLP::FirefoxDriver.method(:build), max_size: 1) }
    let(:screenshot) { TRMNLP::Screenshot.new(pool:) }
    let(:device) { { width: 1872, height: 1404, screen_classes: 'screen screen--4bit screen--v2 screen--lg' } }
    let(:shown) { '[...document.querySelectorAll(".view")].map((view) => view.innerText).join()' }
    let(:rows) { (1..20).map { "<tr><td><span class='label'>Row #{it}</span></td></tr>" }.join }
    let(:table) { %(<table class="table" data-table-limit="true"><tbody>#{rows}</tbody></table>) }
    let(:clamp) { %(<div style="width: 200px"><span class="description" data-clamp="2">#{'word ' * 60}</span></div>) }

    after do
      pool.shutdown
      FileUtils.remove_entry(project_dir)
    end

    def preview(markup)
      FileUtils.mkdir_p(File.join(project_dir, 'src'))
      File.write(File.join(project_dir, '.trmnlp.yml'), '{}')
      File.write(File.join(project_dir, 'src', 'settings.yml'), "framework_version: '#{TRMNLP::FrameworkVersion.latest}'\n")
      File.write(File.join(project_dir, 'src', 'full.liquid'), %(<div class="layout">#{markup}</div>))
      get '/render/full.html', device
      last_response.body
    end

    # The page as a device shows it: laid out unscaled for good, where its scripts measure the CSS size.
    def unscaled(page)
      html = page.sub('</head>', '<style>.trmnl .screen { --pixel-ratio: 1 !important; }</style></head>')
      pool.with_driver do |driver|
        screenshot.show(driver, html, device[:width], device[:height])
        driver.execute_script("return #{shown}")
      end
    end

    def in_browser(page)
      pool.with_driver do |driver|
        screenshot.show(driver, '<html></html>', device[:width], device[:height])
        driver.navigate.to('about:blank')
        driver.execute_script('document.open(); document.write(arguments[0]); document.close();', page)
        Selenium::WebDriver::Wait.new(timeout: 20).until { driver.execute_script("return !document.getElementById('trmnlp-layout-pass')") }
        yield driver
      end
    end

    it 'limits a table to the rows the device shows' do
      page = preview(table)
      expect(in_browser(page) { it.execute_script("return #{shown}") }).to eq(unscaled(page))
    end

    it 'clamps text to the lines the device shows' do
      page = preview(clamp)
      expect(in_browser(page) { it.execute_script("return #{shown}") }).to eq(unscaled(page))
    end

    it 'shows the screen at its CSS size, the size of the preview frame' do
      width = 'return document.querySelector(".screen").getBoundingClientRect().width'
      expect(in_browser(preview(table)) { it.execute_script(width) }).to eq(1040)
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

  describe 'GET /api/config' do
    it 'returns the custom field values from .trmnlp.yml' do
      get '/api/config'

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['custom_fields']).to include('character_name' => 'Bluey')
    end

    it 'returns plugin field definitions, excluding author_bio' do
      definitions = [
        { 'keyname' => 'city', 'field_type' => 'string', 'name' => 'City' },
        { 'keyname' => 'bio', 'field_type' => 'author_bio', 'name' => 'Bio' }
      ]
      allow(context.config.plugin).to receive(:custom_field_definitions).and_return(definitions)

      get '/api/config'

      body = JSON.parse(last_response.body)
      expect(body['plugin_fields'].map { |f| f['keyname'] }).to eq(['city'])
    end
  end

  describe 'POST /api/config' do
    let(:tmp_root) { Dir.mktmpdir }
    let(:config_file) { File.join(tmp_root, '.trmnlp.yml') }
    let(:initial_config) do
      { 'time_zone' => 'America/New_York', 'custom_fields' => { 'character_name' => 'Bluey' } }
    end
    let(:context) do
      File.write(config_file, YAML.dump(initial_config))
      ctx = TRMNLP::Context.new(tmp_root)
      allow(ctx.poller).to receive(:poll_data)
      allow(ctx.config.project).to receive(:live_render?).and_return(false)
      ctx
    end

    after { FileUtils.remove_entry(tmp_root) }

    def post_config(payload)
      post '/api/config', payload, { 'CONTENT_TYPE' => 'application/json' }
    end

    it 'saves the custom fields to .trmnlp.yml and reports them back stringified' do
      post_config({ custom_fields: { character_name: 'Bingo', character_age: 6 } }.to_json)

      expect(last_response.status).to eq(200)
      body = JSON.parse(last_response.body)
      expect(body['success']).to be(true)
      expect(body['custom_fields']).to eq('character_name' => 'Bingo', 'character_age' => '6')
      expect(YAML.safe_load_file(config_file)['custom_fields']).to eq('character_name' => 'Bingo',
                                                                      'character_age' => 6)
    end

    it 'preserves unrelated keys in .trmnlp.yml' do
      post_config({ custom_fields: { character_name: 'Bingo' } }.to_json)

      expect(YAML.safe_load_file(config_file)['time_zone']).to eq('America/New_York')
    end

    it 're-polls so the new values reach polling URLs and headers' do
      post_config({ custom_fields: {} }.to_json)

      expect(context.poller).to have_received(:poll_data).at_least(:twice)
    end

    it 'rejects a body that is not valid JSON' do
      post_config('{nope')

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['error']).to include('not valid JSON')
    end

    it 'rejects a body that is not a JSON object' do
      post_config('[1, 2, 3]')

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['error']).to include('must be a JSON object')
    end

    it 'rejects custom_fields that is not a JSON object' do
      post_config({ custom_fields: 'nope' }.to_json)

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['error']).to include('custom_fields must be a JSON object')
    end

    it 'rejects blank field names' do
      post_config({ custom_fields: { '  ' => 'value' } }.to_json)

      expect(last_response.status).to eq(400)
      expect(JSON.parse(last_response.body)['error']).to include('cannot be blank')
    end

    it 'leaves .trmnlp.yml untouched when validation fails' do
      post_config({ custom_fields: 'nope' }.to_json)

      expect(YAML.safe_load_file(config_file)).to eq(initial_config)
    end

    it 'reports unexpected failures as a 500 error' do
      allow(context.config.project).to receive(:reload!).and_raise(TRMNLP::InvalidConfig, 'boom')

      post_config({ custom_fields: {} }.to_json)

      expect(last_response.status).to eq(500)
      expect(JSON.parse(last_response.body)['error']).to eq('boom')
    end
  end

  describe 'POST /webhook' do
    let(:payload) { '{"merge_variables":{"items":[1,2,3]}}' }

    before do
      allow(context.webhook_receiver).to receive(:call)
        .with(payload, { 'merge_strategy' => 'stream' })
        .and_return([422, { message: 'nope' }])
      post '/webhook?merge_strategy=stream', payload, { 'CONTENT_TYPE' => 'application/json' }
    end

    it 'answers with the status from the receiver' do
      expect(last_response.status).to eq(422)
    end

    it 'answers with the JSON body from the receiver' do
      expect(JSON.parse(last_response.body)).to eq('message' => 'nope')
    end
  end

  describe 'POST /callback' do
    let(:payload) { '{"merge_variables":{"items":[1]}}' }

    before do
      allow(context.async_callback).to receive(:call).with(payload, '3').and_return([410, { message: 'gone' }])
      post '/callback?v=3', payload, { 'CONTENT_TYPE' => 'application/json' }
    end

    it 'answers with the status from the callback' do
      expect(last_response.status).to eq(410)
    end

    it 'answers with the JSON body from the callback' do
      expect(JSON.parse(last_response.body)).to eq('message' => 'gone')
    end
  end
end
