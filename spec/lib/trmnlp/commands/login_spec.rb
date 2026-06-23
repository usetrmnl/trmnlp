# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/commands/login'

RSpec.describe TRMNLP::Commands::Login do
  subject(:command) do
    described_class.new(context:, options: described_class::Options.new(dir: fixtures_root, quiet: true, server: nil))
  end

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

    it 'rejects a key that does not start with user_' do
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

    context 'when --server is given' do
      subject(:command) do
        described_class.new(
          context:,
          options: described_class::Options.new(dir: fixtures_root, quiet: true, server: 'http://localhost')
        )
      end

      it 'saves base_url to the app config' do
        allow(command).to receive(:prompt).and_return('3|sanctumtoken')
        allow(api_client).to receive(:get_me).and_return('name' => 'Bluey', 'email' => 'b@example.com')

        command.call

        expect(app_config.base_uri.to_s).to eq('http://localhost')
      end

      it 'accepts a Sanctum-format token without raising' do
        allow(command).to receive(:prompt).and_return('3|sanctumtoken')
        allow(api_client).to receive(:get_me).and_return('name' => 'Bluey', 'email' => 'b@example.com')

        expect { command.call }.not_to raise_error
      end
    end

    it 'still rejects a non-user_ key when targeting trmnl.com (default)' do
      allow(command).to receive(:prompt).and_return('not_a_user_key')

      expect { command.call }.to raise_error(TRMNLP::InvalidApiKey, /Invalid API key/)
    end
  end
end
