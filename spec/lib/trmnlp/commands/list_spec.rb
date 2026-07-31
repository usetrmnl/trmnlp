# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/commands/list'

RSpec.describe TRMNLP::Commands::List do
  subject(:command) { described_class.new(context:, options:, reporter:) }

  let(:api_client) { instance_double(TRMNLP::APIClient) }
  let(:context) { TRMNLP::Context.new(fixtures_root) }
  let(:fixtures_root) { File.expand_path('../../../fixtures', __dir__) }
  let(:options) { described_class::Options.new(dir: fixtures_root, quiet: true) }
  let(:output) { reporter.messages.join("\n") }
  let(:plugins) { [] }
  let(:reporter) { TRMNLP::Reporter.new(quiet: true) }

  before do
    allow(context.config.app).to receive(:logged_in?).and_return(true)
    allow(TRMNLP::APIClient).to receive(:new).and_return(api_client)
    allow(api_client).to receive(:get_plugin_settings).and_return(plugins)
  end

  describe '#call' do
    context 'when the account has no plugins' do
      it 'reports none were found' do
        command.call

        expect(output).to include('No plugins found')
      end
    end

    context 'when the account is logged out' do
      before { allow(context.config.app).to receive(:logged_in?).and_return(false) }

      it 'raises' do
        expect { command.call }.to raise_error(TRMNLP::NotLoggedIn)
      end
    end

    context 'when the account holds plugins of other types' do
      let(:plugins) do
        [
          { 'id' => 3, 'plugin_id' => 37, 'name' => 'Zebra' },
          { 'id' => 2, 'plugin_id' => 99, 'name' => 'Not Private' },
          { 'id' => 1, 'plugin_id' => 37, 'name' => 'apple' }
        ]
      end

      it 'lists only private plugins' do
        command.call

        expect(output).to include('apple').and include('Zebra')
      end

      it 'skips plugins of other types' do
        command.call

        expect(output).not_to include('Not Private')
      end

      it 'sorts by name regardless of case' do
        command.call

        expect(output.index('apple')).to be < output.index('Zebra')
      end
    end

    context 'when a plugin has a description' do
      let(:plugins) do
        [
          { 'id' => 1, 'plugin_id' => 37, 'name' => 'Hacker News', 'description' => 'Top stories from HN' },
          { 'id' => 2, 'plugin_id' => 37, 'name' => 'Weather' }
        ]
      end

      it 'adds a description column sized to the longest name' do
        command.call

        expect(output).to match(/^  1 {7}  Hacker News  Top stories from HN$/)
      end

      it 'leaves no trailing spaces on a plugin without one' do
        command.call

        expect(output).to match(/^  2 {7}  Weather$/)
      end
    end

    context 'when every description is empty' do
      let(:plugins) { [{ 'id' => 1, 'plugin_id' => 37, 'name' => 'Weather', 'description' => '' }] }

      it 'keeps the two column table' do
        command.call

        expect(output).to match(/^  ID {8}NAME$/)
      end
    end

    context 'when a description holds only spaces' do
      let(:plugins) { [{ 'id' => 1, 'plugin_id' => 37, 'name' => 'Weather', 'description' => '   ' }] }

      it 'keeps the two column table' do
        command.call

        expect(output).to match(/^  ID {8}NAME$/)
      end
    end

    context 'when the server omits the description key' do
      let(:plugins) { [{ 'id' => 1, 'plugin_id' => 37, 'name' => 'Weather' }] }

      it 'keeps the two column table' do
        command.call

        expect(output).to match(/^  ID {8}NAME$/)
      end
    end

    context 'when a BYOS server returns a UUID id alongside a numeric one' do
      let(:plugins) do
        [
          { 'id' => '019bd4c8-1a2f-7c3e-9b5d-4e6f8a0c2d17', 'plugin_id' => nil, 'name' => 'Tide Clock' },
          { 'id' => 91, 'plugin_id' => nil, 'name' => 'Bus Times' }
        ]
      end

      it 'includes plugins with no plugin type' do
        command.call

        expect(output).to include('Tide Clock').and include('Bus Times')
      end

      it 'widens the id column to fit the UUID' do
        command.call

        expect(output).to match(/^  019bd4c8-1a2f-7c3e-9b5d-4e6f8a0c2d17  Tide Clock$/)
      end

      it 'pads the numeric id to the same width' do
        command.call

        expect(output).to match(/^  91 {34}  Bus Times$/)
      end
    end
  end
end
