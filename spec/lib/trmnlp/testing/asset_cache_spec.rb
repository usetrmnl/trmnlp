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

  describe '#rewrite without overrides' do
    it "points the page's Framework stylesheets and scripts at the cache" do
      html = %(<link href="#{css_url}"><script src="https://trmnl.com/js/3.4.2/plugins.js"></script>)
      expect(cache.rewrite(html)).to eq(%(<link href="#{cache.url}/css/3.4.2/plugins.css">) +
                                      %(<script src="#{cache.url}/js/3.4.2/plugins.js"></script>))
    end

    it "points the Framework's Google Fonts stylesheet at the cache" do
      html = '<link href="https://fonts.googleapis.com/css2?family=Inter&amp;display=swap">'
      expect(cache.rewrite(html))
        .to eq(%(<link href="#{cache.url}/fonts.googleapis.com/css2?family=Inter&amp;display=swap">))
    end

    it 'leaves other trmnl.com addresses alone' do
      html = '<img src="https://trmnl.com/images/plugins/weather.svg"><a href="https://trmnl.com/css">x</a>'
      expect(cache.rewrite(html)).to eq(html)
    end
  end

  describe '#rewrite' do
    let(:source) { 'https://example.test/assets/logo.svg' }
    let(:overrides) { { 'https://example.test/assets/' => dir } }

    before { File.write(File.join(dir, 'logo.svg'), '<svg/>') }

    it 'rewrites a prefix in an attribute and an inline script string' do
      html = %(<img src="#{source}"><script>const logo = "#{source}"</script>)
      rewritten = cache.rewrite(html, overrides:)
      expect(rewritten.scan(cache.url).length).to eq(2)
    end

    it 'serves a file from a folder' do
      rewritten = cache.rewrite(%(<img src="#{source}">), overrides:)
      uri = URI(rewritten[/src="([^"]+)/, 1])
      expect(Net::HTTP.get_response(uri)).to have_attributes(code: '200', body: '<svg/>', content_type: 'image/svg+xml')
    end

    it 'uses the longest matching key' do
      File.write(File.join(dir, 'other.svg'), 'specific')
      mapping = overrides.merge(source => File.join(dir, 'other.svg'))
      uri = URI(cache.rewrite(source, overrides: mapping))
      expect(Net::HTTP.get(uri)).to eq('specific')
    end

    it 'reads a changed file on the next request' do
      uri = URI(cache.rewrite(source, overrides:))
      Net::HTTP.get(uri)
      File.write(File.join(dir, 'logo.svg'), 'updated')
      expect(Net::HTTP.get(uri)).to eq('updated')
    end

    it 'fetches a URL target through the cache' do
      target = 'https://mirror.test/logo.svg'
      stub_request(:get, target).to_return(body: 'mirror', headers: { 'content-type' => 'image/svg+xml',
                                                                      'cache-control' => 'max-age=300' })
      uri = URI(cache.rewrite(source, overrides: { source => target }))
      expect(Net::HTTP.get(uri)).to eq('mirror')
    end

    it 'serves inline content with its declared type' do
      uri = URI(cache.rewrite(source, overrides: { source => { body: 'hello', content_type: 'text/plain' } }))
      expect(Net::HTTP.get_response(uri)).to have_attributes(body: 'hello', content_type: 'text/plain')
    end

    it 'guesses the type of inline content from the URL' do
      js = 'https://example.test/app.js'
      uri = URI(cache.rewrite(js, overrides: { js => { body: 'window.ok = true' } }))
      expect(Net::HTTP.get_response(uri).content_type).to eq('text/javascript')
    end

    it 'caches a URL target for the lifetime it declares' do
      target = 'https://mirror.test/logo.svg'
      stub_request(:get, target).to_return(body: 'mirror', headers: { 'cache-control' => 'max-age=300' })
      uri = URI(cache.rewrite(source, overrides: { source => target }))
      Net::HTTP.get(uri)
      Net::HTTP.get(uri)
      expect(a_request(:get, target)).to have_been_made.once
    end

    it 'copies the override into a relative bundle path' do
      rewritten = cache.rewrite(source, overrides:, bundle_dir: dir)
      expect(File.binread(File.join(dir, rewritten))).to eq('<svg/>')
    end

    it 'leaves a page byte for byte unchanged without overrides or framework links' do
      html = "<script>const url = '#{source}'</script>\n"
      expect(cache.rewrite(html)).to eq(html)
    end
  end

  describe '#rewrite_if_configured' do
    it 'keeps a page byte for byte when no overrides are configured' do
      html = %(<link href="#{css_url}">\n)
      expect(cache.rewrite_if_configured(html, overrides: {})).to eq(html)
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

  context 'with a Google Fonts stylesheet' do
    let(:google_css_url) { 'https://fonts.googleapis.com/css2?family=Inter&display=swap' }
    let(:firefox) { 'Mozilla/5.0 (Macintosh; rv:157.0) Gecko/20100101 Firefox/157.0' }
    let(:google_css) { '@font-face { src: url(https://fonts.gstatic.com/s/inter/v20/a.woff2) format("woff2"); }' }

    def get_as_firefox(path)
      Net::HTTP.start('127.0.0.1', URI(cache.url).port) { it.get(path, 'User-Agent' => firefox) }
    end

    before do
      stub_request(:get, google_css_url).with(headers: { 'User-Agent' => firefox })
                                        .to_return(body: google_css, headers: { 'content-type' => 'text/css' })
      stub_request(:get, 'https://fonts.gstatic.com/s/inter/v20/a.woff2')
        .to_return(body: 'inter', headers: { 'content-type' => 'font/woff2' })
    end

    it 'asks Google as Firefox does, and points its font files at the cache' do
      expect(get_as_firefox('/fonts.googleapis.com/css2?family=Inter&display=swap').body)
        .to include("url(#{cache.url}/fonts.gstatic.com/s/inter/v20/a.woff2)")
    end

    it 'keeps each family apart' do
      stub_request(:get, 'https://fonts.googleapis.com/css2?family=Lora')
        .to_return(body: 'lora', headers: { 'content-type' => 'text/css' })
      get_as_firefox('/fonts.googleapis.com/css2?family=Inter&display=swap')
      expect(get_as_firefox('/fonts.googleapis.com/css2?family=Lora').body).to eq('lora')
    end

    it 'serves the font files' do
      expect(get('/fonts.gstatic.com/s/inter/v20/a.woff2').body).to eq('inter')
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
