# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::Poller do
  subject(:poller) { described_class.new(config:, paths:) }

  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:content_type_cases) do
    [
      { name: 'json',
        header: 'application/json; charset=utf-8',
        body: '{"key": "value", "number": 42}',
        parsed: { 'key' => 'value', 'number' => 42 } },
      { name: 'json:api',
        header: 'application/vnd.api+json; charset=utf-8',
        body: '{"data":[{"type": "widget", "id": "1", "attributes": {"title": "foobar", "value": 42}}]}',
        parsed: { 'data' => [{ 'type' => 'widget', 'id' => '1',
                               'attributes' => { 'title' => 'foobar', 'value' => 42 } }] } },
      { name: 'xml',
        header: 'application/xml; charset=utf-8',
        body: '<response attr="foobar"><key>value</key><number>42</number></response>',
        parsed: { 'response' => { 'attr' => 'foobar', 'key' => 'value', 'number' => '42' } } },
      { name: 'soap+xml',
        header: 'application/soap+xml; charset=utf-8',
        body: '<?xml version="1.0" encoding="utf-8"?>' \
              '<soap:Envelope xmlns:soap="http://www.w3.org/2003/05/soap-envelope" ' \
              'xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" ' \
              'xmlns:xsd="http://www.w3.org/2001/XMLSchema">' \
              '<soap:Body><Number>42</Number></soap:Body></soap:Envelope>',
        parsed: { 'Envelope' => { 'xmlns:soap' => 'http://www.w3.org/2003/05/soap-envelope',
                                  'xmlns:xsd' => 'http://www.w3.org/2001/XMLSchema',
                                  'xmlns:xsi' => 'http://www.w3.org/2001/XMLSchema-instance',
                                  'Body' => { 'Number' => '42' } } } },
      { name: 'octet-stream',
        header: 'application/octet-stream',
        body: 'foobar',
        parsed: {} },
      { name: 'html carrying json',
        header: 'text/html; charset=utf-8',
        body: '{"misCATEGORIZED": "but-still-json"}',
        parsed: { 'misCATEGORIZED' => 'but-still-json' } },
      { name: 'html',
        header: 'text/html; charset=utf-8',
        body: '<html>not json</html>',
        parsed: { 'data' => '<html>not json</html>' } },
      { name: 'plain text',
        header: 'text/plain',
        body: 'hello world',
        parsed: { 'data' => 'hello world' } }
    ]
  end
  let(:expected_by_case) { content_type_cases.to_h { |test_case| [test_case[:name], test_case[:parsed]] } }
  let(:headerless_response) { instance_double(Faraday::Response, body: 'foobar', headers: {}, status: 200) }

  describe '#poll_data' do
    let(:faraday_connection) { instance_double(Faraday::Connection) }

    before do
      allow(poller).to receive(:write_user_data)
      allow(Faraday).to receive(:new).and_return(faraday_connection)
    end

    context 'when the plugin polls with a GET request' do
      before do
        allow(config.plugin).to receive_messages(
          polling?: true,
          polling_urls: ['https://example.com/api'],
          polling_headers: { 'content-type' => 'application/json' },
          polling_verb: 'GET'
        )
      end

      it 'parses every content type into the expected hash' do
        parsed_by_case = content_type_cases.to_h do |test_case|
          response = instance_double(Faraday::Response, body: test_case[:body], status: 200,
                                                        headers: { 'content-type' => test_case[:header] })
          allow(faraday_connection).to receive(:get).and_return(response)
          [test_case[:name], poller.poll_data]
        end

        expect(parsed_by_case).to eq(expected_by_case)
      end

      it 'writes the parsed response to user data' do
        json_case = content_type_cases.first
        response = instance_double(Faraday::Response, body: json_case[:body], status: 200,
                                                      headers: { 'content-type' => json_case[:header] })
        allow(faraday_connection).to receive(:get).and_return(response)

        poller.poll_data

        expect(poller).to have_received(:write_user_data).with(json_case[:parsed])
      end

      context 'when the response carries no content-type header' do
        before { allow(faraday_connection).to receive(:get).and_return(headerless_response) }

        it 'parses to an empty hash' do
          expect(poller.poll_data).to eq({})
        end
      end
    end

    context 'when the plugin polls with a POST request' do
      before do
        allow(config.plugin).to receive_messages(
          polling?: true,
          polling_urls: ['https://example.com/api'],
          polling_headers: { 'content-type' => 'application/json' },
          polling_verb: 'POST'
        )
      end

      it 'parses every content type into the expected hash' do
        parsed_by_case = content_type_cases.to_h do |test_case|
          response = instance_double(Faraday::Response, body: test_case[:body], status: 200,
                                                        headers: { 'content-type' => test_case[:header] })
          allow(faraday_connection).to receive(:post).and_return(response)
          [test_case[:name], poller.poll_data]
        end

        expect(parsed_by_case).to eq(expected_by_case)
      end

      context 'when the response carries no content-type header' do
        before { allow(faraday_connection).to receive(:post).and_return(headerless_response) }

        it 'parses to an empty hash' do
          expect(poller.poll_data).to eq({})
        end
      end
    end

    context 'when the plugin is not configured for polling' do
      before { allow(config.plugin).to receive(:polling?).and_return(false) }

      it 'returns nil' do
        expect(poller.poll_data).to be_nil
      end

      it 'makes no request' do
        poller.poll_data

        expect(poller).not_to have_received(:write_user_data)
      end
    end
  end
end
