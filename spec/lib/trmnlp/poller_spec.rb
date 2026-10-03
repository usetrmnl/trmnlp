# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::Poller do
  subject(:poller) { described_class.new(config:, paths:, oauth_session:) }

  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:oauth_session) { instance_double(TRMNLP::OAuth::Session, liquid_variables: {}) }
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
        parsed: { 'data' => 'hello world' } },
      { name: 'csv',
        header: 'text/csv',
        body: "a,b\n1,2\n",
        parsed: { data: [%w[a b], %w[1 2]] } },
      { name: 'markdown',
        header: 'text/markdown',
        body: '# Hi',
        parsed: { 'data' => '# Hi' } },
      { name: 'json behind a byte order mark',
        header: 'application/json',
        body: "\xEF\xBB\xBF{\"a\": 1}",
        parsed: { 'a' => 1 } },
      { name: 'json under an unlisted type',
        header: 'application/octet-stream',
        body: '{"a": 1}',
        parsed: { 'a' => 1 } }
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

      context 'when the response is not a 200' do
        subject(:poller) { described_class.new(config:, paths:, oauth_session:, reporter:) }

        let(:reporter) { TRMNLP::Reporter.new(quiet: true) }
        let(:json_headers) { { 'content-type' => 'application/json' } }

        it 'parses the body of a 202, like the hosted service' do
          response = instance_double(Faraday::Response, body: '{"step": "pending"}', status: 202, headers: json_headers)
          allow(faraday_connection).to receive(:get).and_return(response)

          expect(poller.poll_data).to eq({ 'step' => 'pending' })
        end

        it 'still parses the body of a client error' do
          response = instance_double(Faraday::Response, body: '{"error": "nope"}', status: 404, headers: json_headers)
          allow(faraday_connection).to receive(:get).and_return(response)

          expect(poller.poll_data).to eq({ 'error' => 'nope' })
        end

        it 'warns about a client error' do
          response = instance_double(Faraday::Response, body: '{}', status: 404, headers: json_headers)
          allow(faraday_connection).to receive(:get).and_return(response)
          poller.poll_data

          expect(reporter.messages).to include(a_string_matching(/HTTP 404 from/))
        end

        it 'drops the body of a server error, as the hosted service does' do
          response = instance_double(Faraday::Response, body: '{"error": "nope"}', status: 500, headers: json_headers)
          allow(faraday_connection).to receive(:get).and_return(response)

          expect(poller.poll_data).to eq({})
        end

        it 'names the server error' do
          response = instance_double(Faraday::Response, body: '{}', status: 503, headers: json_headers)
          allow(faraday_connection).to receive(:get).and_return(response)
          poller.poll_data

          expect(reporter.messages).to include(a_string_matching(/Unable to fetch .* — the host replied 503/))
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

    context 'when an oauth session is connected' do
      before do
        allow(config.plugin).to receive_messages(
          polling?: true, polling_verb: 'GET',
          polling_urls: ['https://example.com/api'], polling_headers: {}
        )
        allow(oauth_session).to receive(:liquid_variables).and_return('oauth_access_token' => 'AT')
        allow(faraday_connection).to receive(:get).and_return(headerless_response)
      end

      it 'threads the oauth variables into the polling headers render' do
        poller.poll_data

        expect(config.plugin).to have_received(:polling_headers)
          .with(extra_variables: { 'oauth_access_token' => 'AT' })
      end

      it 'threads the oauth variables into the polling urls render' do
        poller.poll_data

        expect(config.plugin).to have_received(:polling_urls)
          .with(extra_variables: { 'oauth_access_token' => 'AT' })
      end

      context 'when the provider rejects the token with a 401' do
        let(:unauthorized) { instance_double(Faraday::Response, body: '', status: 401, headers: {}) }
        let(:authorized) do
          instance_double(Faraday::Response, body: '{"ok": 1}', status: 200,
                                             headers: { 'content-type' => 'application/json' })
        end

        before do
          allow(oauth_session).to receive(:liquid_variables)
            .and_return({ 'oauth_access_token' => 'AT' }, { 'oauth_access_token' => 'AT2' })
          allow(faraday_connection).to receive(:get).and_return(unauthorized, authorized)
        end

        context 'and the token refreshes' do
          before { allow(oauth_session).to receive(:force_refresh!).and_return(instance_double(TRMNLP::OAuth::TokenBundle)) }

          it 'polls again with the refreshed token' do
            poller.poll_data

            expect(config.plugin).to have_received(:polling_urls)
              .with(extra_variables: { 'oauth_access_token' => 'AT2' })
          end

          it 'answers the retried response' do
            expect(poller.poll_data).to eq({ 'ok' => 1 })
          end
        end

        context 'and there is nothing to refresh' do
          before { allow(oauth_session).to receive(:force_refresh!).and_return(nil) }

          it 'polls once' do
            poller.poll_data

            expect(faraday_connection).to have_received(:get).once
          end
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

  describe '#poll_data against a real request' do
    subject(:poller) { described_class.new(config:, paths:, oauth_session:, reporter:, trmnl_variables:) }

    let(:reporter) { TRMNLP::Reporter.new(quiet: true) }
    let(:trmnl_variables) { -> { { 'trmnl' => { 'user' => { 'time_zone_iana' => 'Europe/Paris' } } } } }
    let(:cache_dir) { Pathname.new(Dir.mktmpdir) }
    let(:fields) { [{ 'keyname' => 'api_key' }] }

    before do
      allow(paths).to receive(:cache_dir).and_return(cache_dir)
      url = 'https://a.test/?tz={{ trmnl.user.time_zone_iana }}&key={{ api_key }}'
      settings = { 'strategy' => 'polling', 'custom_fields' => fields, 'polling_url' => url }
      config.plugin.instance_variable_set(:@config, settings)
    end

    after { FileUtils.remove_entry(cache_dir) }

    context 'when a field the url needs is blank' do
      it 'skips polling' do
        page = stub_request(:get, /a\.test/)
        poller.poll_data

        expect(page).not_to have_been_requested
      end

      it 'names the blank field' do
        poller.poll_data

        expect(reporter.messages).to include(a_string_matching(/Plugin is not configured — fill in: api_key/))
      end
    end

    context 'when every field is filled in' do
      before { allow(config.project).to receive(:custom_fields).and_return('api_key' => 'abc') }

      it 'renders the trmnl namespace into the url' do
        page = stub_request(:get, 'https://a.test/?tz=Europe/Paris&key=abc').to_return(body: '{}')
        poller.poll_data

        expect(page).to have_been_requested
      end

      it 'leaves the query string, which may hold an api key, out of a warning' do
        stub_request(:get, /a\.test/).to_return(status: 500)
        poller.poll_data

        expect(reporter.messages.grep(/Unable to fetch/))
          .to eq(['warning: Unable to fetch data from url: https://a.test/ — the host replied 500'])
      end

      it 'leaves the query string out of the request log' do
        stub_request(:get, /a\.test/).to_return(body: '{}')
        poller.poll_data

        expect(reporter.messages.grep(/received/)).to eq(['GET https://a.test/ — received 2 bytes (200 status)'])
      end

      it 'warns about malformed JSON' do
        stub_request(:get, /a\.test/).to_return(body: 'nope', headers: { 'Content-Type' => 'application/json' })
        poller.poll_data

        expect(reporter.messages).to include(a_string_matching(/Malformed JSON from url/))
      end
    end
  end
end
