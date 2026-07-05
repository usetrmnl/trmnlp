# frozen_string_literal: true

require 'spec_helper'
require 'cgi'

RSpec.describe TRMNLP::OAuth::Client do
  subject(:client) { described_class.new(provider) }

  let(:provider) { TRMNLP::OAuth::Provider.new(config) }
  let(:config) do
    {
      'authorize_url' => 'https://provider.test/authorize',
      'token_url' => 'https://provider.test/token',
      'scopes' => 'read write',
      'client_id' => 'cid',
      'client_secret' => 'secret'
    }
  end
  let(:redirect_uri) { 'http://localhost:4567/oauth/callback' }
  let(:token_response) do
    { access_token: 'AT', refresh_token: 'RT', expires_in: 3600, token_type: 'bearer' }
  end

  describe '#authorize_url' do
    it 'requests the authorization code grant with the configured params' do
      url = client.authorize_url(redirect_uri:, state: 'xyz')

      expect(CGI.unescape(url)).to include(
        'response_type=code', 'client_id=cid', 'state=xyz',
        'scope=read write', "redirect_uri=#{redirect_uri}"
      )
    end

    context 'with a PKCE challenge' do
      it 'includes the S256 code challenge' do
        url = client.authorize_url(redirect_uri:, state: 'xyz', code_challenge: 'chal')

        expect(url).to include('code_challenge=chal', 'code_challenge_method=S256')
      end
    end
  end

  describe '#exchange_code' do
    before do
      stub_request(:post, 'https://provider.test/token').to_return(
        status: 200, body: token_response.to_json, headers: { 'Content-Type' => 'application/json' }
      )
    end

    it 'returns the token bundle' do
      expect(client.exchange_code(code: 'thecode', redirect_uri:))
        .to have_attributes(access_token: 'AT', refresh_token: 'RT', token_type: 'bearer')
    end

    it 'resolves expires_in into an absolute expires_at' do
      expect(client.exchange_code(code: 'thecode', redirect_uri:).expires_at).to be > Time.now.to_i
    end

    context 'with a PKCE code verifier' do
      it 'sends the verifier in the token request' do
        client.exchange_code(code: 'thecode', redirect_uri:, code_verifier: 'the-verifier')

        expect(a_request(:post, 'https://provider.test/token')
          .with(body: hash_including('code_verifier' => 'the-verifier'))).to have_been_made
      end
    end

    context 'as a public client without a secret' do
      let(:config) { super().except('client_secret').merge('pkce' => true) }

      it 'sends the client_id in the request body' do
        client.exchange_code(code: 'thecode', redirect_uri:)

        expect(a_request(:post, 'https://provider.test/token')
          .with(body: hash_including('client_id' => 'cid'))).to have_been_made
      end
    end
  end

  describe '#refresh' do
    before do
      stub_request(:post, 'https://provider.test/token').to_return(
        status: 200, body: token_response.merge(access_token: 'AT2').to_json,
        headers: { 'Content-Type' => 'application/json' }
      )
    end

    it 'returns the refreshed bundle' do
      expect(client.refresh(refresh_token: 'RT').access_token).to eq('AT2')
    end

    it 'sends the refresh_token grant' do
      client.refresh(refresh_token: 'RT')

      expect(a_request(:post, 'https://provider.test/token')
        .with(body: hash_including('grant_type' => 'refresh_token'))).to have_been_made
    end

    context 'with a distinct refresh_url' do
      let(:config) { super().merge('refresh_url' => 'https://provider.test/refresh') }

      before do
        stub_request(:post, 'https://provider.test/refresh').to_return(
          status: 200, body: token_response.merge(access_token: 'AT3').to_json,
          headers: { 'Content-Type' => 'application/json' }
        )
      end

      it 'refreshes against the refresh_url' do
        expect(client.refresh(refresh_token: 'RT').access_token).to eq('AT3')
      end
    end
  end
end
