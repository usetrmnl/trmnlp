# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/transform_client'

RSpec.describe TRMNLP::UserDataAssembler do
  subject(:assembler) { described_class.new(config:, paths:, transform_pipeline:) }

  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:transform_pipeline) { TRMNLP::TransformPipeline.new(config:, paths:) }
  let(:cache_dir) { Pathname.new(Dir.mktmpdir) }

  before { allow(paths).to receive(:cache_dir).and_return(cache_dir) }
  after { FileUtils.remove_entry(cache_dir) }

  describe '#call' do
    before do
      allow(config.plugin).to receive(:static?).and_return(false)
    end

    context 'without device overrides' do
      it 'uses the default device dimensions' do
        expect(assembler.call.dig('trmnl', 'device', 'width')).to eq(800)
        expect(assembler.call.dig('trmnl', 'device', 'height')).to eq(480)
      end
    end

    it 'fills the device status and schedule the hosted service sends' do
      expect(assembler.call['trmnl']['device']).to include(
        'model' => 'og_plus', 'bit_depth' => 2, 'firmware_version' => '1.8.17', 'refresh_interval_seconds' => 900,
        'sleep_mode_enabled' => false, 'sleep_start_time' => 1320, 'sleep_end_time' => 480
      )
    end

    it 'defaults the device to landscape' do
      expect(assembler.call.dig('trmnl', 'device', 'orientation')).to eq('landscape')
    end

    it 'names the instance after the plugin' do
      allow(config.plugin).to receive(:settings).and_return('name' => 'Kevin Bacon Facts')

      expect(assembler.call.dig('trmnl', 'plugin_settings', 'instance_name')).to eq('Kevin Bacon Facts')
    end

    it 'includes no_screen_padding in the plugin settings' do
      allow(config.plugin).to receive(:no_screen_padding).and_return('yes')

      expect(assembler.call.dig('trmnl', 'plugin_settings', 'no_screen_padding')).to eq('yes')
    end

    it 'never includes the polling headers' do
      expect(assembler.call.dig('trmnl', 'plugin_settings')).not_to have_key('polling_headers')
    end

    it 'leaves out the polling url for a plugin that does not poll' do
      allow(config.plugin).to receive(:polling?).and_return(false)

      expect(assembler.call.dig('trmnl', 'plugin_settings')).not_to have_key('polling_url')
    end

    it 'includes the polling url for a polling plugin' do
      allow(config.plugin).to receive_messages(polling?: true, polling_url_text: 'https://example.com')

      expect(assembler.call.dig('trmnl', 'plugin_settings', 'polling_url')).to eq('https://example.com')
    end

    it 'leaves out data_fetched_utc before any data was fetched' do
      expect(assembler.call.dig('trmnl', 'plugin_settings')).not_to have_key('data_fetched_utc')
    end

    it 'stamps data_fetched_utc with the time the stored data was fetched' do
      paths.user_data.dirname.mkpath
      paths.user_data.write('{}')
      File.utime(Time.at(1_759_000_000), Time.at(1_759_000_000), paths.user_data)

      expect(assembler.call.dig('trmnl', 'plugin_settings', 'data_fetched_utc')).to eq(1_759_000_000)
    end

    it 'keeps its own trmnl namespace over a trmnl key in the fetched data, as TRMNL does' do
      paths.user_data.dirname.mkpath
      paths.user_data.write('{"trmnl":{"plugin_settings":{"instance_name":"Other"}}}')
      allow(config.plugin).to receive(:settings).and_return('name' => 'Mine')

      expect(assembler.call.dig('trmnl', 'plugin_settings', 'instance_name')).to eq('Mine')
    end

    it 'answers an empty trmnl.state before a transform kept one' do
      expect(assembler.call.dig('trmnl', 'state')).to eq({})
    end

    it 'reads the refresh interval from the plugin settings' do
      allow(config.plugin).to receive(:refresh_interval).and_return(60)

      expect(assembler.call.dig('trmnl', 'plugin_settings', 'refresh_interval_minutes')).to eq(60)
    end

    context 'with device overrides from the picker' do
      it 'uses the supplied dimensions (issue #94)' do
        data = assembler.call(device: { 'width' => 400, 'height' => 240 })

        expect(data.dig('trmnl', 'device', 'width')).to eq(400)
        expect(data.dig('trmnl', 'device', 'height')).to eq(240)
      end

      it 'uses the picked orientation' do
        data = assembler.call(device: { 'orientation' => 'portrait' })

        expect(data.dig('trmnl', 'device', 'orientation')).to eq('portrait')
      end

      it 'uses the picked model and bit depth' do
        data = assembler.call(device: { 'model' => 'v2', 'bit_depth' => 4 })

        expect(data['trmnl']['device']).to include('model' => 'v2', 'bit_depth' => 4)
      end
    end

    context 'with trmnl namespace overrides in .trmnlp variables' do
      before do
        allow(config.project).to receive(:user_data_overrides).and_return(
          'trmnl' => {
            'user' => {
              'time_zone' => 'Central Time (US & Canada)',
              'time_zone_iana' => 'America/Chicago',
              'utc_offset' => -18_000
            }
          }
        )
      end

      it 'applies the overrides to the trmnl namespace (regression: overrides were dropped after transform)' do
        data = assembler.call

        expect(data.dig('trmnl', 'user', 'time_zone')).to eq('Central Time (US & Canada)')
        expect(data.dig('trmnl', 'user', 'time_zone_iana')).to eq('America/Chicago')
        expect(data.dig('trmnl', 'user', 'utc_offset')).to eq(-18_000)
      end

      it 'does not clobber other trmnl namespace keys' do
        data = assembler.call

        expect(data.dig('trmnl', 'device', 'width')).to eq(800)
        expect(data.dig('trmnl', 'user', 'locale')).to eq('en')
      end
    end

    it 'includes a user id, matching the hosted trmnl.user shape' do
      expect(assembler.call.dig('trmnl', 'user', 'id')).to eq(1)
    end
  end

  describe '#device_from_params' do
    it 'extracts width and height from string params' do
      expect(assembler.device_from_params(width: '400', height: '240'))
        .to eq('width' => 400, 'height' => 240)
    end

    it 'extracts the model and bit depth' do
      expect(assembler.device_from_params(model: 'v2', bit_depth: '4')).to eq('model' => 'v2', 'bit_depth' => 4)
    end

    it 'extracts the orientation' do
      expect(assembler.device_from_params(orientation: 'portrait')).to eq('orientation' => 'portrait')
    end

    it 'returns an empty hash when neither param is present' do
      expect(assembler.device_from_params({})).to eq({})
    end
  end

  describe '#call (through the transform pipeline)' do
    let(:transform_client) { instance_double(TRMNLP::TransformClient) }
    let(:transform_path) { Pathname.new('/tmp/fake-transform.py') }

    before do
      allow(config.plugin).to receive(:static?).and_return(true)
      allow(config.plugin).to receive_messages(
        static_data: { 'items' => [1, 2, 3] },
        serverless_language: nil
      )
      allow(paths).to receive(:transform_file).and_return([transform_path, 'python'])
      allow(transform_path).to receive(:read).and_return('# transform code')
      allow(transform_path).to receive(:extname).and_return('.py')
      allow(transform_path).to receive(:exist?).and_return(true)
      allow(TRMNLP::TransformClient).to receive(:from_config).and_return(transform_client)
    end

    context 'when the plugin uses static strategy and a transform is configured' do
      before do
        allow(transform_client).to receive(:execute).and_return(
          TRMNLP::TransformClient::Result.new(
            stdout: '', stderr: '', output: '{"items":[2,4,6]}', exit_code: 0, duration_ms: 5, error: nil
          )
        )
      end

      it 'runs the transform against static_data (matches the hosted pipeline)' do
        result = assembler.call
        expect(result['items']).to eq([2, 4, 6])
      end

      it 'forwards the assembled data (including trmnl namespace) to the transform' do
        assembler.call

        expect(transform_client).to have_received(:execute) do |kwargs|
          stdin = JSON.parse(kwargs[:stdin])
          expect(stdin['items']).to eq([1, 2, 3])
          expect(stdin['trmnl']['device']['width']).to eq(800)
        end
      end

      it 'preserves the trmnl namespace even when the transform omits it' do
        result = assembler.call
        expect(result.dig('trmnl', 'device', 'width')).to eq(800)
      end

      it 'excludes the system namespace from the transform input (matches the hosted slice)' do
        assembler.call

        expect(transform_client).to have_received(:execute) do |kwargs|
          trmnl = JSON.parse(kwargs[:stdin])['trmnl']
          expect(trmnl.keys).to contain_exactly('user', 'device', 'plugin_settings', 'state',
                                                'previous_merge_variables')
        end
      end

      it 'keeps the system namespace in the final result (slice is transform-input only)' do
        expect(assembler.call.dig('trmnl', 'system', 'timestamp_utc')).to be_a(Integer)
      end
    end

    context 'when the transform has run before' do
      let(:inputs_received) { [] }

      before do
        allow(transform_client).to receive(:execute) do |kwargs|
          inputs_received << JSON.parse(kwargs[:stdin])
          TRMNLP::TransformClient::Result.new(
            stdout: '', stderr: '', output: '{"items":[2,4,6]}', exit_code: 0, duration_ms: 5, error: nil
          )
        end
      end

      it 'passes the last output as trmnl.previous_merge_variables' do
        2.times { assembler.call }

        previous = inputs_received.map { it.dig('trmnl', 'previous_merge_variables') }

        expect(previous).to eq([{}, { 'items' => [2, 4, 6] }])
      end
    end

    context 'with a webhook plugin' do
      let(:inputs_received) { [] }

      before do
        allow(config.plugin).to receive_messages(static?: false, webhook?: true)
        paths.user_data.dirname.mkpath
        paths.user_data.write('{"items":[5]}')
        allow(transform_client).to receive(:execute) do |kwargs|
          inputs_received << JSON.parse(kwargs[:stdin])
          TRMNLP::TransformClient::Result.new(
            stdout: '', stderr: '', output: '{"items":[70]}', exit_code: 0, duration_ms: 5, error: nil
          )
        end
      end

      it 'renders the stored data without running the transform' do
        expect(assembler.call['items']).to eq([5])
      end

      it 'runs no transform on render' do
        assembler.call

        expect(transform_client).not_to have_received(:execute)
      end

      it 'transforms a post with the posted merge_variables' do
        expect(assembler.transform_webhook_post('items' => [7])).to eq('items' => [70])
      end

      it 'passes the posted merge_variables to the transform' do
        assembler.transform_webhook_post('items' => [7])

        expect(inputs_received.first['items']).to eq([7])
      end

      it 'passes the stored data to a post as trmnl.previous_merge_variables' do
        assembler.transform_webhook_post('items' => [7])

        expect(inputs_received.first.dig('trmnl', 'previous_merge_variables')).to eq('items' => [5])
      end
    end

    context 'when the transform returns a trmnl_state' do
      let(:result) do
        TRMNLP::TransformClient::Result.new(
          stdout: '', stderr: '', output: '{"items":[],"trmnl_state":{"etag":"abc"}}', exit_code: 0,
          duration_ms: 5, error: nil
        )
      end
      let(:states_received) { [] }

      before do
        allow(transform_client).to receive(:execute) do |kwargs|
          states_received << JSON.parse(kwargs[:stdin]).dig('trmnl', 'state')
          result
        end
      end

      it 'renders the new state as trmnl.state' do
        expect(assembler.call.dig('trmnl', 'state')).to eq('etag' => 'abc')
      end

      it 'passes it to the next run of the transform' do
        2.times { assembler.call }

        expect(states_received).to eq([{}, { 'etag' => 'abc' }])
      end
    end

    context 'when the transform fails' do
      before do
        allow(transform_client).to receive(:execute).and_return(
          TRMNLP::TransformClient::Result.new(
            stdout: '', stderr: 'KaBoom', output: '', exit_code: 1, duration_ms: 5, error: nil
          )
        )
      end

      it 'falls back to the untransformed data and records the error on the pipeline' do
        result = assembler.call
        expect(result['items']).to eq([1, 2, 3])
        expect(transform_pipeline.error).to include('KaBoom')
      end
    end
  end
end
