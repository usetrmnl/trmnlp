require 'spec_helper'

RSpec.describe TRMNLP::Context do
  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  subject(:context) { described_class.new(root_dir) }

  # Context#poll_data and #put_webhook use puts/print for logging.
  # Silence them so test output stays clean.
  before { allow($stdout).to receive(:write) }

  TEST_RESPONSES = [
    {
      header: 'application/json; charset=utf-8',
      response_body: '{"key": "value", "number": 42}',
      parsed: { 'key' => 'value', 'number' => 42 }
    },
    {
      header: 'application/vnd.api+json; charset=utf-8',
      response_body: '{"data":[{"type": "widget", "id": "1", "attributes": {"title": "foobar", "value": 42}}]}',
      parsed: { 'data' => [{'type' => "widget", 'id' => "1", 'attributes' => {"title" => "foobar", "value" => 42}}] }
    },
    {
      header: 'application/xml; charset=utf-8',
      response_body: '<response attr="foobar"><key>value</key><number>42</number></response>',
      parsed: { 'response' => { 'attr' => 'foobar', 'key' => 'value', 'number' => '42' } }
    },
    {
      header: 'application/soap+xml; charset=utf-8',
      response_body: '<?xml version="1.0" encoding="utf-8"?><soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema"><soap:Body><Number>42</Number></soap:Body></soap:Envelope>',
      parsed: { 'Envelope' => { 'xmlns:soap' => 'http://www.w3.org/2003/05/soap-envelope', 'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema', 'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance', 'Body' => { 'Number' => '42' } } }
    },
    {
      header: 'application/octet-stream',
      response_body: 'foobar',
      parsed: {}
    }
  ].freeze

  describe '#poll_data' do
    let(:faraday_connection) { instance_double(Faraday::Connection) }
    let(:faraday_no_header_response) { instance_double(Faraday::Response, body: 'foobar', headers: {}, status: 200) }

    before do
      allow(context).to receive(:write_user_data)
      allow(Faraday).to receive(:new).and_return(faraday_connection)
    end

    describe 'when plugin is configured for polling' do
      before do
        allow(context.config.plugin).to receive(:polling?)
          .and_return(true)
        allow(context.config.plugin).to receive(:polling_urls)
          .and_return(['https://example.com/api'])
        allow(context.config.plugin).to receive(:polling_headers)
          .and_return({ 'content-type' => 'application/json' })
      end

      context 'when plugin is configured for a GET request' do
        before do
          allow(context.config.plugin).to receive(:polling_verb)
            .and_return('GET')
        end

        TEST_RESPONSES.each do |test_response|
          context "when the response has a content type of #{test_response[:header]}" do
            before do
              allow(faraday_connection).to receive(:get).and_return(instance_double(Faraday::Response, body: test_response[:response_body], headers: { 'content-type' => test_response[:header] }, status: 200))
            end

            it 'calls write_user_data with the parsed response data as a hash' do
              context.poll_data

              expect(context).to have_received(:write_user_data).with(test_response[:parsed])
            end

            it 'returns the parsed response data as a hash' do
              result = context.poll_data

              expect(result).to eq(test_response[:parsed])
            end
          end
        end

        context 'when the response has no content type header' do
          before do
            allow(faraday_connection).to receive(:get).and_return(faraday_no_header_response)
          end

          it 'calls write_user_data with an empty hash from the response' do
            context.poll_data

            expect(context).to have_received(:write_user_data).with({})
          end

          it 'returns an empty hash' do
            result = context.poll_data

            expect(result).to eq({})
          end
        end
      end

      context 'when plugin is configured for a POST request' do
        before do
          allow(context.config.plugin).to receive(:polling_verb)
            .and_return('POST')
        end

        TEST_RESPONSES.each do |test_response|
          context "when the response has a content type of #{test_response[:header]}" do
            before do
              allow(faraday_connection).to receive(:post).and_return(instance_double(Faraday::Response, body: test_response[:response_body], headers: { 'content-type' => test_response[:header] }, status: 200))
            end

            it 'calls write_user_data with the parsed response data as a hash' do
              context.poll_data

              expect(context).to have_received(:write_user_data).with(test_response[:parsed])
            end

            it 'returns the parsed response data as a hash' do
              result = context.poll_data

              expect(result).to eq(test_response[:parsed])
            end
          end
        end

        context 'when the response has no content type header' do
          before do
            allow(faraday_connection).to receive(:post).and_return(faraday_no_header_response)
          end

          it 'calls write_user_data with an empty hash from the response' do
            context.poll_data

            expect(context).to have_received(:write_user_data).with({})
          end

          it 'returns an empty hash' do
            result = context.poll_data

            expect(result).to eq({})
          end
        end
      end
    end

    context 'when plugin is not configured for polling' do
      before do
        allow(context.config.plugin).to receive(:polling?).and_return(false)
      end

      it 'returns nil without making any requests' do
        result = context.poll_data

        expect(result).to be_nil
        expect(context).not_to have_received(:write_user_data)
      end
    end
  end

  describe '#put_webhook' do
    before { allow(context).to receive(:write_user_data) }

    it 'parses JSON payload and writes user_data' do
      context.put_webhook('{"key": "value"}')
      expect(context).to have_received(:write_user_data).with({ 'key' => 'value' })
    end

    it 'wraps array payloads under a data key' do
      context.put_webhook('[1, 2, 3]')
      expect(context).to have_received(:write_user_data).with({ data: [1, 2, 3] })
    end

    it 'logs an error on invalid JSON without raising' do
      expect { context.put_webhook('not json {') }.not_to raise_error
      expect(context).not_to have_received(:write_user_data)
    end
  end

  describe '#validate!' do
    context 'when .trmnlp.yml exists' do
      it 'does not raise' do
        expect { context.validate! }.not_to raise_error
      end
    end

    context 'when .trmnlp.yml does not exist' do
      let(:root_dir) { Dir.mktmpdir }

      after { FileUtils.rm_rf(root_dir) }

      it 'raises TRMNLP::Error' do
        expect { context.validate! }.to raise_error(TRMNLP::Error, /not a plugin directory/)
      end
    end
  end

  describe '#user_data' do
    it 'includes base trmnl mock data' do
      data = context.user_data
      expect(data).to have_key('trmnl')
      expect(data['trmnl']['user']['name']).to eq('name')
      expect(data['trmnl']['device']['friendly_id']).to eq('ABC123')
      expect(data['trmnl']['system']).to have_key('timestamp_utc')
    end

    it 'merges static data from plugin config' do
      data = context.user_data
      expect(data['message']).to eq('hello from fixture')
    end

    it 'includes plugin_settings in trmnl data' do
      data = context.user_data
      settings = data['trmnl']['plugin_settings']
      expect(settings['strategy']).to eq('static')
    end
  end

  describe '#render_liquid_template' do
    it 'renders the template with user_data variables' do
      result = context.render_liquid_template('full')
      expect(result).to include('hello from fixture')
    end

    it 'returns an error message for a missing template' do
      result = context.render_liquid_template('nonexistent')
      expect(result).to include('Missing template')
    end
  end

  describe '#render_full_page' do
    it 'wraps rendered Liquid in the TRMNL HTML shell' do
      result = context.render_full_page('full')
      expect(result).to include('<!DOCTYPE html>')
      expect(result).to include('environment trmnl')
      expect(result).to include('hello from fixture')
      expect(result).to include('view--full')
    end
  end
end
