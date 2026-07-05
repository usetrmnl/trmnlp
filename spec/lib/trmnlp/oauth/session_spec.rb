# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe TRMNLP::OAuth::Session do
  subject(:session) { described_class.new(provider:, token_store:, client:) }

  let(:provider) { TRMNLP::OAuth::Provider.new(config) }
  let(:config) do
    {
      'authorize_url' => 'https://provider.test/authorize',
      'token_url' => 'https://provider.test/token',
      'scopes' => 'read',
      'client_id' => 'cid',
      'client_secret' => 'secret'
    }
  end
  let(:tmpdir) { Pathname(Dir.mktmpdir) }
  let(:token_store) { TRMNLP::OAuth::TokenStore.new(tmpdir.join('tokens.json')) }
  let(:client) { instance_double(TRMNLP::OAuth::Client) }

  let(:valid_bundle) do
    TRMNLP::OAuth::TokenBundle.new(access_token: 'AT', refresh_token: 'RT',
                                   expires_at: Time.now.to_i + 3600, token_type: 'Bearer')
  end
  let(:expired_bundle) { valid_bundle.with(expires_at: Time.now.to_i - 10) }
  let(:refreshed_bundle) do
    TRMNLP::OAuth::TokenBundle.new(access_token: 'AT2', refresh_token: 'RT2',
                                   expires_at: Time.now.to_i + 3600, token_type: 'Bearer')
  end

  after { FileUtils.remove_entry(tmpdir) if tmpdir.exist? }

  describe '#configured?' do
    it 'delegates to the provider' do
      expect(session).to be_configured
    end
  end

  describe '#pkce?' do
    it 'delegates to the provider' do
      expect(session).not_to be_pkce
    end
  end

  describe '#connected?' do
    it 'is not connected without a stored token' do
      expect(session).not_to be_connected
    end

    context 'with a stored token' do
      before { token_store.write(valid_bundle) }

      it 'is connected' do
        expect(session).to be_connected
      end
    end
  end

  describe '#access_token' do
    it 'returns nil without a stored token' do
      expect(session.access_token).to be_nil
    end

    context 'with a valid token' do
      before { token_store.write(valid_bundle) }

      it 'returns the stored token without refreshing' do
        expect(session.access_token).to eq('AT')
      end
    end

    context 'with an expired token' do
      before do
        token_store.write(expired_bundle)
        allow(client).to receive(:refresh).with(refresh_token: 'RT').and_return(refreshed_bundle)
      end

      it 'refreshes and returns the new token' do
        expect(session.access_token).to eq('AT2')
      end

      it 'persists the refreshed bundle' do
        session.access_token

        expect(token_store.read.access_token).to eq('AT2')
      end
    end

    context 'when the refresh omits a new refresh_token' do
      before do
        token_store.write(expired_bundle)
        allow(client).to receive(:refresh).and_return(refreshed_bundle.with(refresh_token: nil))
      end

      it 'keeps the previous refresh_token' do
        session.access_token

        expect(token_store.read.refresh_token).to eq('RT')
      end
    end

    context 'when the refresh fails' do
      before do
        token_store.write(expired_bundle)
        allow(client).to receive(:refresh).and_raise(StandardError, 'boom')
      end

      it 'raises a RefreshError naming the reconnect path' do
        expect { session.access_token }.to raise_error(TRMNLP::OAuth::RefreshError, %r{/oauth/connect})
      end
    end
  end

  describe '#liquid_variables' do
    it 'returns no variables when not connected' do
      expect(session.liquid_variables).to eq({})
    end

    context 'when connected' do
      before { token_store.write(valid_bundle) }

      it 'exposes the oauth variables' do
        expect(session.liquid_variables).to eq(
          'oauth_access_token' => 'AT', 'oauth_token_type' => 'Bearer', 'oauth_client_id' => 'cid'
        )
      end
    end
  end

  describe '#complete' do
    before { allow(client).to receive(:exchange_code).and_return(valid_bundle) }

    it 'stores the exchanged bundle' do
      session.complete(code: 'thecode', redirect_uri: 'http://localhost:4567/oauth/callback')

      expect(token_store.read).to eq(valid_bundle)
    end
  end

  describe '#authorize_url' do
    before { allow(client).to receive(:authorize_url).and_return('https://provider.test/authorize?x=1') }

    it 'delegates to the client' do
      expect(session.authorize_url(redirect_uri: 'http://localhost:4567/oauth/callback', state: 's'))
        .to eq('https://provider.test/authorize?x=1')
    end
  end

  describe '#disconnect' do
    before do
      token_store.write(valid_bundle)
      session.disconnect
    end

    it 'clears the connection' do
      expect(session).not_to be_connected
    end
  end
end
