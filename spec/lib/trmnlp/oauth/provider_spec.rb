# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::OAuth::Provider do
  subject(:provider) { described_class.new(config, env:) }

  let(:config) { {} }
  let(:env) { {} }
  let(:full_config) do
    {
      'authorize_url' => 'https://provider.test/authorize',
      'token_url' => 'https://provider.test/token',
      'scopes' => 'read:user user:email',
      'client_id' => 'client-abc',
      'pkce' => true
    }
  end

  describe '#authorize_url, #token_url, #scopes, #client_id' do
    let(:config) { full_config }

    it 'expose the configured values' do
      expect(provider).to have_attributes(
        authorize_url: 'https://provider.test/authorize',
        token_url: 'https://provider.test/token',
        scopes: 'read:user user:email',
        client_id: 'client-abc'
      )
    end
  end

  describe '#refresh_url' do
    let(:config) { { 'token_url' => 'https://provider.test/token' } }

    it 'falls back to the token_url' do
      expect(provider.refresh_url).to eq('https://provider.test/token')
    end

    context 'when set explicitly' do
      let(:config) { super().merge('refresh_url' => 'https://provider.test/refresh') }

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
      let(:config) { { 'scope_separator' => ',' } }

      it 'uses the configured separator' do
        expect(provider.scope_separator).to eq(',')
      end
    end
  end

  describe '#pkce?' do
    it 'defaults to false' do
      expect(provider).not_to be_pkce
    end

    context 'when enabled' do
      let(:config) { { 'pkce' => true } }

      it 'is true' do
        expect(provider).to be_pkce
      end
    end
  end

  describe '#client_secret' do
    let(:config) { { 'client_secret' => 'from-yaml' } }

    it 'falls back to the yaml value when the env var is absent' do
      expect(provider.client_secret).to eq('from-yaml')
    end

    context 'when the env var is set' do
      let(:env) { { 'TRMNL_OAUTH_CLIENT_SECRET' => 'from-env' } }

      it 'prefers the env var' do
        expect(provider.client_secret).to eq('from-env')
      end
    end

    context 'when the env var is blank' do
      let(:env) { { 'TRMNL_OAUTH_CLIENT_SECRET' => '' } }

      it 'falls back to the yaml value' do
        expect(provider.client_secret).to eq('from-yaml')
      end
    end
  end

  describe '#configured?' do
    context 'with a PKCE provider and no secret' do
      let(:config) { full_config }

      it 'is configured' do
        expect(provider).to be_configured
      end
    end

    context 'with a secret and no PKCE' do
      let(:config) { full_config.merge('pkce' => false, 'client_secret' => 'shh') }

      it 'is configured' do
        expect(provider).to be_configured
      end
    end

    context 'without PKCE or a secret' do
      let(:config) { full_config.merge('pkce' => false) }

      it 'is not configured' do
        expect(provider).not_to be_configured
      end
    end

    context 'without a client_id' do
      let(:config) { full_config.except('client_id') }

      it 'is not configured' do
        expect(provider).not_to be_configured
      end
    end

    context 'with an empty config' do
      it 'is not configured' do
        expect(provider).not_to be_configured
      end
    end
  end
end
