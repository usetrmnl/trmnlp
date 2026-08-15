# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/commands/login'

RSpec.describe TRMNLP::Commands::Login do
  subject(:command) do
    described_class.new(context:, options: described_class::Options.new(dir: fixtures_root, quiet: true, server:))
  end

  let(:server) { nil }
  let(:api_client) { instance_double(TRMNLP::APIClient) }
  let(:fixtures_root) { File.expand_path('../../../fixtures', __dir__) }
  let(:context) { TRMNLP::Context.new(fixtures_root) }
  let(:app_config) { context.config.app }

  before do
    allow(app_config).to receive(:logged_in?).and_return(false)
    allow(app_config).to receive(:save)
    allow(app_config).to receive(:api_key=)
    allow(TRMNLP::APIClient).to receive(:new).and_return(api_client)
  end

  describe '#call' do
    it 'rejects an empty API key' do
      allow(command).to receive(:prompt).and_return('')
      expect { command.call }.to raise_error(TRMNLP::InvalidApiKey, /cannot be empty/)
    end

    it 'rejects a trmnl.com key that is not user_-prefixed' do
      allow(command).to receive(:prompt).and_return('not_a_user_key')
      expect { command.call }.to raise_error(TRMNLP::InvalidApiKey, /Invalid API key/)
    end

    it 'verifies the key against /me and saves on success' do
      allow(command).to receive(:prompt).and_return('user_abc123')
      allow(api_client).to receive(:get_me).and_return('name' => 'Bluey', 'email' => 'b@example.com')

      command.call

      expect(app_config).to have_received(:save)
    end

    it 'raises and does not save when verification fails' do
      allow(command).to receive(:prompt).and_return('user_abc123')
      allow(api_client).to receive(:get_me).and_raise(TRMNLP::Error, 'HTTP 401')

      expect { command.call }.to raise_error(TRMNLP::AuthenticationFailed, /Authentication failed/)
      expect(app_config).not_to have_received(:save)
    end

    context 'when already authenticated and re-authentication is declined' do
      before do
        allow(app_config).to receive(:logged_in?).and_return(true)
        allow(app_config).to receive(:api_key).and_return('user_existing_key')
        allow(command).to receive(:prompt).and_return('n')
      end

      it 'aborts without saving' do
        command.call
        expect(app_config).not_to have_received(:save)
      end
    end

    context 'when --server targets a BYOS host' do
      let(:server) { 'http://localhost' }

      before do
        allow(command).to receive(:prompt).and_return('3|sanctumtoken')
        allow(api_client).to receive(:get_me).and_return('name' => 'Bluey', 'email' => 'b@example.com')
      end

      it 'persists the server as the base_uri' do
        command.call
        expect(app_config.base_uri.to_s).to eq('http://localhost')
      end

      it 'accepts a non-user_ token without raising' do
        expect { command.call }.not_to raise_error
      end
    end

    context 'when --server is scheme-less' do
      let(:server) { 'localhost:3000' }

      it 'does not crash on the host check' do
        allow(command).to receive(:prompt).and_return('3|sanctumtoken')
        allow(api_client).to receive(:get_me).and_return('name' => 'Bluey', 'email' => 'b@example.com')

        expect { command.call }.not_to raise_error
      end
    end
  end
end
