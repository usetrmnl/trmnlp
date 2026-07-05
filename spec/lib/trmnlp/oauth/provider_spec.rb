# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::OAuth::Provider do
  subject(:provider) { described_class.new(settings, env:) }

  let(:settings) { {} }
  let(:env) { {} }
  let(:full_settings) do
    {
      'oauth_enabled' => 'true',
      'oauth_authorize_url' => 'https://provider.test/authorize',
      'oauth_token_url' => 'https://provider.test/token',
      'oauth_scopes' => 'read:user user:email',
      'oauth_pkce_enabled' => 'true'
    }
  end

  describe '#authorize_url, #token_url, #scopes' do
    let(:settings) { full_settings }

    it 'read the flat oauth_* keys from settings.yml' do
      expect(provider).to have_attributes(
        authorize_url: 'https://provider.test/authorize',
        token_url: 'https://provider.test/token',
        scopes: 'read:user user:email'
      )
    end
  end

  describe '#refresh_url' do
    let(:settings) { { 'oauth_token_url' => 'https://provider.test/token' } }

    it 'falls back to the token_url' do
      expect(provider.refresh_url).to eq('https://provider.test/token')
    end

    context 'when set explicitly' do
      let(:settings) { super().merge('oauth_refresh_url' => 'https://provider.test/refresh') }

      it 'uses the configured refresh_url' do
        expect(provider.refresh_url).to eq('https://provider.test/refresh')
      end
    end
  end

  describe '#scope_separator' do
    it 'defaults to a single space' do
      expect(provider.scope_separator).to eq(' ')
    end

    context 'when configured' do
      let(:settings) { { 'oauth_scope_separator' => ',' } }

      it 'uses the configured separator' do
        expect(provider.scope_separator).to eq(',')
      end
    end
  end

  describe '#pkce?' do
    it 'defaults to false' do
      expect(provider).not_to be_pkce
    end

    context "when enabled with the string 'true'" do
      let(:settings) { { 'oauth_pkce_enabled' => 'true' } }

      it 'is true' do
        expect(provider).to be_pkce
      end
    end

    context 'when enabled with a boolean' do
      let(:settings) { { 'oauth_pkce_enabled' => true } }

      it 'is true' do
        expect(provider).to be_pkce
      end
    end
  end

  describe '#client_id' do
    let(:settings) { { 'oauth_client_id' => 'from-settings' } }

    it 'falls back to the settings value when the env var is absent' do
      expect(provider.client_id).to eq('from-settings')
    end

    context 'when the env var is set' do
      let(:env) { { 'TRMNL_OAUTH_CLIENT_ID' => 'from-env' } }

      it 'prefers the env var' do
        expect(provider.client_id).to eq('from-env')
      end
    end
  end

  describe '#client_secret' do
    let(:settings) { { 'oauth_client_secret' => 'from-settings' } }

    it 'falls back to the settings value when the env var is absent' do
      expect(provider.client_secret).to eq('from-settings')
    end

    context 'when the env var is set' do
      let(:env) { { 'TRMNL_OAUTH_CLIENT_SECRET' => 'from-env' } }

      it 'prefers the env var' do
        expect(provider.client_secret).to eq('from-env')
      end
    end
  end

  describe '#configured?' do
    let(:env) { { 'TRMNL_OAUTH_CLIENT_ID' => 'cid' } }

    context 'with a PKCE provider and no secret' do
      let(:settings) { full_settings }

      it 'is configured' do
        expect(provider).to be_configured
      end
    end

    context 'with a secret and no PKCE' do
      let(:settings) { full_settings.merge('oauth_pkce_enabled' => 'false') }
      let(:env) { super().merge('TRMNL_OAUTH_CLIENT_SECRET' => 'shh') }

      it 'is configured' do
        expect(provider).to be_configured
      end
    end

    context 'when oauth is disabled' do
      let(:settings) { full_settings.merge('oauth_enabled' => 'false') }

      it 'is not configured' do
        expect(provider).not_to be_configured
      end
    end

    context 'without a client_id' do
      let(:settings) { full_settings }
      let(:env) { {} }

      it 'is not configured' do
        expect(provider).not_to be_configured
      end
    end

    context 'without PKCE or a secret' do
      let(:settings) { full_settings.merge('oauth_pkce_enabled' => 'false') }

      it 'is not configured' do
        expect(provider).not_to be_configured
      end
    end
  end
end
