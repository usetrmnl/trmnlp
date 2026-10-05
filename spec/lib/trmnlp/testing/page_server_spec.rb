# frozen_string_literal: true

require 'net/http'
require 'spec_helper'
require 'trmnlp/testing/page_server'

RSpec.describe TRMNLP::Testing::PageServer do
  subject(:server) { described_class.new.start }

  let(:url) { server.add('<p>héllo</p>') }

  before { WebMock.allow_net_connect! }

  after do
    server.stop
    WebMock.disable_net_connect!(allow_localhost: true)
  end

  def get(address) = Net::HTTP.get_response(URI(address))

  it 'serves a page at an address of its own' do
    expect(get(url)).to have_attributes(code: '200', body: '<p>héllo</p>'.b)
  end

  it 'says the page is UTF-8, and not to be kept' do
    expect(get(url).to_hash).to include('content-type' => ['text/html; charset=utf-8'], 'cache-control' => ['no-store'])
  end

  it 'gives every page another address on the same host, so they share what Firefox has parsed' do
    other = server.add('<p>other</p>')

    expect([other == url, URI(other).then { [it.host, it.port] }]).to eq([false, URI(url).then { [it.host, it.port] }])
  end

  it 'answers 404 for a page it has forgotten' do
    server.forget(url)

    expect(get(url).code).to eq('404')
  end

  it 'answers 404 for anything else' do
    expect(get(URI.join(url, '/favicon.ico').to_s).code).to eq('404')
  end
end
