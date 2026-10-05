# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/update_check'

RSpec.describe TRMNLP::UpdateCheck do
  subject(:check) { described_class.new(reporter:) }

  let(:reporter) { TRMNLP::Reporter.new(stream: StringIO.new) }
  let(:endpoint) { 'https://rubygems.org/api/v1/gems/trmnl_preview.json' }

  before do
    stub_request(:get, endpoint).to_return(body: { version: '99.0.0' }.to_json)
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('BUNDLE_GEMFILE').and_return(nil)
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
