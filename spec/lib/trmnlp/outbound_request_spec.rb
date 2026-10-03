# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::OutboundRequest do
  subject(:request) { described_class.new }

  let(:headers) { { 'Authorization' => 'Bearer abc' } }

  def get(url, body: nil) = request.call('GET', url, headers:, body:)

  it 'answers the response' do
    stub_request(:get, 'https://a.test/data').to_return(body: '{}')

    expect(get('https://a.test/data').first.body).to eq('{}')
  end

  it 'follows a redirect' do
    stub_request(:get, 'https://a.test/old').to_return(status: 301, headers: { 'Location' => '/new' })
    stub_request(:get, 'https://a.test/new').to_return(body: 'moved')

    expect(get('https://a.test/old').first.body).to eq('moved')
  end

  it 'keeps Authorization on a redirect to the same host' do
    stub_request(:get, 'https://a.test/old').to_return(status: 302, headers: { 'Location' => '/new' })
    new_page = stub_request(:get, 'https://a.test/new').with(headers: { 'Authorization' => 'Bearer abc' })
    get('https://a.test/old')

    expect(new_page).to have_been_requested
  end

  it 'drops Authorization on a redirect to another host' do
    stub_request(:get, 'https://a.test/old').to_return(status: 302, headers: { 'Location' => 'https://b.test/new' })
    other_host = stub_request(:get, 'https://b.test/new').with { |req| !req.headers.key?('Authorization') }
    get('https://a.test/old')

    expect(other_host).to have_been_requested
  end

  it 'turns a POST into a GET on a 302' do
    stub_request(:post, 'https://a.test/old').to_return(status: 302, headers: { 'Location' => '/new' })
    new_page = stub_request(:get, 'https://a.test/new')
    request.call('POST', 'https://a.test/old', headers:, body: 'x=1')

    expect(new_page).to have_been_requested
  end

  it 'keeps a POST on a 307' do
    stub_request(:post, 'https://a.test/old').to_return(status: 307, headers: { 'Location' => '/new' })
    new_page = stub_request(:post, 'https://a.test/new').with(body: 'x=1')
    request.call('POST', 'https://a.test/old', headers:, body: 'x=1')

    expect(new_page).to have_been_requested
  end

  it 'stops after 5 redirects' do
    stub_request(:get, %r{https://a\.test/loop}).to_return(status: 302, headers: { 'Location' => '/loop' })

    expect(get('https://a.test/loop').first.status).to eq(302)
  end

  it 'fails a 429' do
    stub_request(:get, 'https://a.test/data').to_return(status: 429)

    expect(get('https://a.test/data')).to eq([nil, 'the host replied 429 Too Many Requests'])
  end

  it 'fails a server error' do
    stub_request(:get, 'https://a.test/data').to_return(status: 502)

    expect(get('https://a.test/data')).to eq([nil, 'the host replied 502'])
  end

  it 'answers a client error, whose body still renders' do
    stub_request(:get, 'https://a.test/data').to_return(status: 404, body: 'gone')

    expect(get('https://a.test/data').first.body).to eq('gone')
  end

  it 'retries a timeout once' do
    stub_request(:get, 'https://a.test/data').to_timeout.then.to_return(body: 'late')

    expect(get('https://a.test/data').first.body).to eq('late')
  end

  it 'fails after a second timeout' do
    stub_request(:get, 'https://a.test/data').to_timeout

    expect(get('https://a.test/data')).to eq([nil, 'no response within 10s'])
  end

  it 'sends a GET body as the query string' do
    page = stub_request(:get, 'https://a.test/data?a=1&b=2')
    get('https://a.test/data?a=1', body: 'b=2')

    expect(page).to have_been_requested
  end

  it 'percent-encodes non-ASCII characters after the host' do
    page = stub_request(:get, 'https://a.test/caf%C3%A9')
    get('https://a.test/café')

    expect(page).to have_been_requested
  end

  it 'reports a private address' do
    reported = []
    stub_request(:get, 'http://127.0.0.1/data')
    local_request = described_class.new(on_private_address: ->(url) { reported << url })
    local_request.call('GET', 'http://127.0.0.1/data', headers: {}, body: nil)

    expect(reported).to eq(['http://127.0.0.1/data'])
  end

  it 'still fetches a private address, which a self-hosted server can reach' do
    stub_request(:get, 'http://127.0.0.1/data').to_return(body: 'local')

    expect(get('http://127.0.0.1/data').first.body).to eq('local')
  end

  describe '.private_address?' do
    it 'answers true for a LAN address' do
      expect(described_class.private_address?('http://192.168.1.10/api')).to be(true)
    end

    it 'answers false for a public address' do
      expect(described_class.private_address?('https://1.1.1.1/')).to be(false)
    end
  end
end
