# frozen_string_literal: true

require 'net/http'
require 'spec_helper'
require 'tmpdir'
require 'trmnlp/testing/asset_cache'

RSpec.describe TRMNLP::Testing::AssetCache do
  subject(:cache) { described_class.new(dir:, clock: -> { now.first }).start }

  let(:dir) { Dir.mktmpdir('trmnlp-assets-') }
  let(:now) { [Time.utc(2030, 1, 1)] }
  let(:css_url) { 'https://trmnl.com/css/3.4.2/plugins.css' }
  let(:font_url) { 'https://trmnl.com/fonts/TRMNL16-Regular.woff2' }

  before do
    WebMock.disable_net_connect!(allow_localhost: true)
    stub_request(:get, css_url).to_return(body: '.title {}', headers: { 'content-type' => 'text/css',
                                                                        'cache-control' => 'max-age=31536000' })
    stub_request(:get, font_url).to_return(body: 'font', headers: { 'content-type' => 'font/woff2',
                                                                    'cache-control' => 'public, max-age=14400',
                                                                    'access-control-allow-origin' => '*' })
  end

  after { cache.stop }

  def get(path) = Net::HTTP.get_response(URI("#{cache.url}#{path}"))

  describe '#point_framework_links_at_cache' do
    it "points the page's Framework stylesheets and scripts at the cache" do
      html = %(<link href="#{css_url}"><script src="https://trmnl.com/js/3.4.2/plugins.js"></script>)
      expect(cache.point_framework_links_at_cache(html)).to eq(%(<link href="#{cache.url}/css/3.4.2/plugins.css">) +
                                      %(<script src="#{cache.url}/js/3.4.2/plugins.js"></script>))
    end

    it 'leaves other trmnl.com addresses alone' do
      html = '<img src="https://trmnl.com/images/plugins/weather.svg"><a href="https://trmnl.com/css">x</a>'
      expect(cache.point_framework_links_at_cache(html)).to eq(html)
    end
  end

  context 'when the file is not cached' do
    it 'serves it from trmnl.com with its type' do
      expect(get('/css/3.4.2/plugins.css')).to have_attributes(code: '200', body: '.title {}', content_type: 'text/css')
    end

    it 'serves a binary file byte for byte' do
      stub_request(:get, font_url).to_return(body: "wOF2\xFF\x00\xC3".b, headers: { 'content-type' => 'font/woff2' })
      expect(get('/fonts/TRMNL16-Regular.woff2').body).to eq("wOF2\xFF\x00\xC3".b)
    end

    it 'passes on how long Firefox may keep it, as trmnl.com says' do
      expect(get('/css/3.4.2/plugins.css')['cache-control']).to eq('max-age=31536000')
    end

    it 'passes on who may load it, so a font loads as it does from trmnl.com' do
      expect(get('/fonts/TRMNL16-Regular.woff2')['access-control-allow-origin']).to eq('*')
    end

    it 'asks as a page does, so a module script trmnl.com lets any page load still loads' do
      js_url = 'https://trmnl.com/js/3.4.2/plugins.js'
      stub_request(:get, js_url).to_return(body: 'export {}')
      stub_request(:get, js_url).with(headers: { 'Origin' => /./ })
                                .to_return(body: 'export {}', headers: { 'access-control-allow-origin' => '*' })
      expect(get('/js/3.4.2/plugins.js')['access-control-allow-origin']).to eq('*')
    end

    it 'still serves it when the cache cannot be written' do
      FileUtils.chmod(0o500, dir)
      expect(get('/css/3.4.2/plugins.css')).to have_attributes(code: '200', body: '.title {}')
    ensure
      FileUtils.chmod(0o700, dir)
    end

    it 'answers 502 when trmnl.com cannot be reached' do
      stub_request(:get, css_url).to_raise(SocketError)
      expect(get('/css/3.4.2/plugins.css').code).to eq('502')
    end
  end

  context 'when the file is cached' do
    before { get('/css/3.4.2/plugins.css') }

    it 'serves it without asking trmnl.com again' do
      get('/css/3.4.2/plugins.css')
      expect(a_request(:get, css_url)).to have_been_made.once
    end

    it 'keeps it for the next run' do
      described_class.new(dir:, clock: -> { now.first }).start.tap do |next_run|
        Net::HTTP.get_response(URI("#{next_run.url}/css/3.4.2/plugins.css"))
        next_run.stop
      end
      expect(a_request(:get, css_url)).to have_been_made.once
    end
  end

  context 'when the cached file is older than trmnl.com says to keep it' do
    before do
      get('/fonts/TRMNL16-Regular.woff2')
      now[0] += 14_401
    end

    it 'downloads it again' do
      stub_request(:get, font_url).to_return(body: 'new font', headers: { 'cache-control' => 'max-age=14400' })
      expect(get('/fonts/TRMNL16-Regular.woff2').body).to eq('new font')
    end

    it 'serves the old copy when trmnl.com cannot be reached' do
      stub_request(:get, font_url).to_raise(SocketError)
      expect(get('/fonts/TRMNL16-Regular.woff2').body).to eq('font')
    end
  end
end
