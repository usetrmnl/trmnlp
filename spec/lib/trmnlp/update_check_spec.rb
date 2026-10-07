# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/update_check'

RSpec.describe TRMNLP::UpdateCheck do
  subject(:check) { described_class.new(cache_path, reporter:) }

  let(:tmp_dir) { Dir.mktmpdir('trmnlp-update-check-') }
  let(:cache_path) { File.join(tmp_dir, 'cache', 'update_check.json') }
  let(:reporter) { TRMNLP::Reporter.new(stream: StringIO.new) }
  let(:endpoint) { 'https://rubygems.org/api/v1/gems/trmnl_preview.json' }

  before do
    stub_request(:get, endpoint).to_return(body: { version: '99.0.0' }.to_json)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return(nil)
  end

  after { FileUtils.rm_rf(tmp_dir) }

  def write_cache(version:, age:)
    FileUtils.mkdir_p(File.dirname(cache_path))
    File.write(cache_path, { checked_at: Time.now.to_i - age, version: }.to_json)
  end

  it 'reports both the installed and newer published version' do
    check.call

    expect(reporter.messages.first).to eq("trmnl_preview 99.0.0 is available (installed: #{TRMNLP::VERSION}).")
  end

  it 'suggests a gem update for a direct install' do
    check.call

    expect(reporter.messages.last).to eq('Update with: gem update trmnl_preview')
  end

  it 'explains the Gemfile constraint before suggesting a Bundler update' do
    allow(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return('/project/Gemfile')
    check.call

    expect(reporter.messages.last).to eq(
      'Update the trmnl_preview constraint in your Gemfile if needed, then run: bundle update trmnl_preview'
    )
  end

  it 'treats an empty BUNDLE_GEMFILE as a direct install' do
    allow(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return('')
    check.call

    expect(reporter.messages.last).to eq('Update with: gem update trmnl_preview')
  end

  it 'compares versions numerically' do
    stub_const('TRMNLP::VERSION', '0.9.0')
    stub_request(:get, endpoint).to_return(body: { version: '0.10.0' }.to_json)
    check.call

    expect(reporter.messages.first).to eq('trmnl_preview 0.10.0 is available (installed: 0.9.0).')
  end

  [TRMNLP::VERSION, '0.0.1'].each do |published|
    it "does not recommend upgrading to #{published}" do
      stub_request(:get, endpoint).to_return(body: { version: published }.to_json)
      check.call

      expect(reporter.messages).to be_empty
    end
  end

  describe 'caching' do
    it 'remembers the published version' do
      check.call

      expect(JSON.parse(File.read(cache_path))).to include('version' => '99.0.0')
    end

    it 'asks RubyGems once for two checks on the same day' do
      check.call
      described_class.new(cache_path, reporter:).call

      expect(WebMock).to have_requested(:get, endpoint).once
    end

    it 'reports from the cache without a request' do
      write_cache(version: '99.0.0', age: 60)
      check.call

      expect(WebMock).not_to have_requested(:get, endpoint)
    end

    it 'reports the cached version' do
      write_cache(version: '98.0.0', age: 60)
      check.call

      expect(reporter.messages.first).to eq("trmnl_preview 98.0.0 is available (installed: #{TRMNLP::VERSION}).")
    end

    it 'asks RubyGems again after a day' do
      write_cache(version: '98.0.0', age: described_class::CACHE_TTL + 1)
      check.call

      expect(reporter.messages.first).to eq("trmnl_preview 99.0.0 is available (installed: #{TRMNLP::VERSION}).")
    end

    it 'stays quiet when the cached release is no newer than the installed one' do
      write_cache(version: TRMNLP::VERSION, age: 60)
      check.call

      expect(reporter.messages).to be_empty
    end

    it 'remembers a failed lookup so an offline day stalls once' do
      stub_request(:get, endpoint).to_timeout
      check.call
      described_class.new(cache_path, reporter:).call

      expect(WebMock).to have_requested(:get, endpoint).once
    end

    it 'asks RubyGems when the cache is unreadable' do
      FileUtils.mkdir_p(File.dirname(cache_path))
      File.write(cache_path, 'not JSON')
      check.call

      expect(WebMock).to have_requested(:get, endpoint).once
    end

    it 'asks RubyGems when the cache has no timestamp' do
      FileUtils.mkdir_p(File.dirname(cache_path))
      File.write(cache_path, { version: '98.0.0' }.to_json)
      check.call

      expect(WebMock).to have_requested(:get, endpoint).once
    end

    it 'still reports when the cache cannot be written' do
      FileUtils.mkdir_p(File.dirname(cache_path))
      FileUtils.chmod(0o500, File.dirname(cache_path))
      check.call

      expect(reporter.messages.first).to start_with('trmnl_preview 99.0.0 is available')
    ensure
      FileUtils.chmod(0o700, File.dirname(cache_path))
    end

    it 'ignores the cache when asked for a fresh answer' do
      write_cache(version: '98.0.0', age: 60)
      check.call(fresh: true)

      expect(reporter.messages.first).to eq("trmnl_preview 99.0.0 is available (installed: #{TRMNLP::VERSION}).")
    end

    it 'refreshes the cache with a fresh answer' do
      write_cache(version: '98.0.0', age: 60)
      check.call(fresh: true)

      expect(JSON.parse(File.read(cache_path))).to include('version' => '99.0.0')
    end
  end

  describe '.disabled?' do
    it 'is false by default' do
      allow(ENV).to receive(:[]).with('TRMNLP_NO_UPDATE_NOTIFIER').and_return(nil)

      expect(described_class).not_to be_disabled
    end

    it 'is true when TRMNLP_NO_UPDATE_NOTIFIER is set' do
      allow(ENV).to receive(:[]).with('TRMNLP_NO_UPDATE_NOTIFIER').and_return('1')

      expect(described_class).to be_disabled
    end
  end

  it 'handles a timeout without raising' do
    stub_request(:get, endpoint).to_timeout
    check.call

    expect(reporter.messages).to be_empty
  end

  it 'handles a connection failure without raising' do
    stub_request(:get, endpoint).to_raise(SocketError)
    check.call

    expect(reporter.messages).to be_empty
  end

  it 'handles a non-success HTTP response' do
    stub_request(:get, endpoint).to_return(status: 503, body: { version: '99.0.0' }.to_json)
    check.call

    expect(reporter.messages).to be_empty
  end

  ['not JSON', '[]', '{}', '{"version":null}', '{"version":12}', '{"version":""}',
   '{"version":"invalid"}', '{"version":"99.0.0.pre"}'].each do |body|
    it "handles an invalid release response #{body.inspect}" do
      stub_request(:get, endpoint).to_return(body:)
      check.call

      expect(reporter.messages).to be_empty
    end
  end

  it 'bounds both connection and read timeouts' do
    options = nil
    allow(Faraday).to receive(:get).and_wrap_original do |original, *args, &block|
      original.call(*args) do |request|
        block.call(request)
        options = [request.options.open_timeout, request.options.timeout]
      end
    end
    check.call

    expect(options).to eq([2, 2])
  end
end
