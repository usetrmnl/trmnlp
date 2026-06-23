# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/commands/list'

RSpec.describe TRMNLP::Commands::List do
  subject(:command) do
    described_class.new(
      context:,
      options: described_class::Options.new(dir: fixtures_root, quiet: true),
      reporter:
    )
  end

  let(:api_client) { instance_double(TRMNLP::APIClient) }
  let(:fixtures_root) { File.expand_path('../../../fixtures', __dir__) }
  let(:context) { TRMNLP::Context.new(fixtures_root) }
  let(:reporter) { TRMNLP::Reporter.new(quiet: true) }

  before do
    allow(context.config.app).to receive(:logged_in?).and_return(true)
    allow(TRMNLP::APIClient).to receive(:new).and_return(api_client)
  end

  describe '#call' do
    it 'lists only private plugins (plugin_id 37), sorted by name' do
      allow(api_client).to receive(:get_plugin_settings).and_return([
                                                                      { 'id' => 3, 'plugin_id' => 37,
                                                                        'name' => 'Zebra' },
                                                                      { 'id' => 2, 'plugin_id' => 99,
                                                                        'name' => 'Not Private' },
                                                                      { 'id' => 1, 'plugin_id' => 37,
                                                                        'name' => 'apple' }
                                                                    ])

      command.call
      output = reporter.messages.join("\n")

      expect(output).to include('apple')
      expect(output).to include('Zebra')
      expect(output).not_to include('Not Private')
      expect(output.index('apple')).to be < output.index('Zebra') # case-insensitive sort
    end

    it 'reports "No plugins found" when the user has none' do
      allow(api_client).to receive(:get_plugin_settings).and_return([])

      command.call

      expect(reporter.messages).to include(match(/No plugins found/))
    end

    it 'includes plugins with a nil plugin_id (BYOS servers like LaraPaper)' do
      plugins = [{ 'id' => 'uuid-1', 'plugin_id' => nil, 'name' => 'My BYOS Plugin' }]
      allow(api_client).to receive(:get_plugin_settings).and_return(plugins)

      command.call

      expect(reporter.messages.join("\n")).to include('My BYOS Plugin')
    end

    it 'raises when not authenticated' do
      allow(context.config.app).to receive(:logged_in?).and_return(false)

      expect { command.call }.to raise_error(TRMNLP::NotLoggedIn)
    end
  end
end
