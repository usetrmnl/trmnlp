require 'spec_helper'

RSpec.describe TRMNLP::Context do
  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  subject(:context) { described_class.new(root_dir) }

  describe '#poll_data' do
    let(:json_response_body) { '{"key": "value", "number": 42}' }
    let(:json_response_parsed) { { 'key' => 'value', 'number' => 42 } }
    let(:xml_response_body) { '<response attr="foobar"><key>value</key><number>42</number></response>' }
    let(:xml_response_parsed) { { 'response' => { 'attr' => 'foobar', 'key' => 'value', 'number' => '42' } } }
    let(:faraday_connection) { instance_double(Faraday::Connection) }
    let(:faraday_json_response) { instance_double(Faraday::Response, body: json_response_body, headers: { 'content-type' => 'application/json' }, status: 200) }
    let(:faraday_xml_response) { instance_double(Faraday::Response, body: xml_response_body, headers: { 'content-type' => 'application/xml' }, status: 200) }
    let(:faraday_octetstream_response) { instance_double(Faraday::Response, body: 'foobar', headers: { 'content-type' => 'application/octet-stream' }, status: 200) }
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

        context 'when the response has a content type of application/json' do
          before do
            allow(faraday_connection).to receive(:get).and_return(faraday_json_response)
          end

          it 'calls write_user_data with the parsed JSON from the response' do
            context.poll_data

            expect(context).to have_received(:write_user_data).with(json_response_parsed)
          end

          it 'returns the parsed JSON data' do
            result = context.poll_data

            expect(result).to eq(json_response_parsed)
          end
        end

        context 'when the response has a content type of application/xml' do
          before do
            allow(faraday_connection).to receive(:get).and_return(faraday_xml_response)
          end

          it 'calls write_user_data with the parsed XML from the response as a hash' do
            context.poll_data

            expect(context).to have_received(:write_user_data).with(xml_response_parsed)
          end

          it 'returns the parsed XML data as a hash' do
            result = context.poll_data

            expect(result).to eq(xml_response_parsed)
          end
        end

        context 'when the response has a content type of octet-stream' do
          before do
            allow(faraday_connection).to receive(:get).and_return(faraday_octetstream_response)
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

        context 'when the response has a content type of application/json' do
          before do
            allow(faraday_connection).to receive(:post).and_return(faraday_json_response)
          end

          it 'calls write_user_data with the parsed JSON from the response' do
            context.poll_data

            expect(context).to have_received(:write_user_data).with(json_response_parsed)
          end

          it 'returns the parsed JSON data' do
            result = context.poll_data

            expect(result).to eq(json_response_parsed)
          end
        end

        context 'when the response has a content type of application/xml' do
          before do
            allow(faraday_connection).to receive(:post).and_return(faraday_xml_response)
          end

          it 'calls write_user_data with the parsed XML from the response as a hash' do
            context.poll_data

            expect(context).to have_received(:write_user_data).with(xml_response_parsed)
          end

          it 'returns the parsed XML data as a hash' do
            result = context.poll_data

            expect(result).to eq(xml_response_parsed)
          end
        end

        context 'when the response has a content type of octet stream' do
          before do
            allow(faraday_connection).to receive(:post).and_return(faraday_octetstream_response)
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
end
