require 'spec_helper'

RSpec.describe TRMNLP::Context do
  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  subject(:context) { described_class.new(root_dir) }

  describe '#poll_data' do
    let(:response_body) { '{"key": "value", "number": 42}' }
    let(:parsed_json) { { 'key' => 'value', 'number' => 42 } }
    let(:faraday_connection) { instance_double(Faraday::Connection) }
    let(:faraday_get_response) { instance_double(Faraday::Response, body: response_body, status: 200) }

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
          allow(faraday_connection).to receive(:get).and_return(faraday_get_response)
          allow(context.config.plugin).to receive(:polling_verb)
            .and_return('GET')
        end

        it 'calls write_user_data with the parsed JSON from the response' do
          context.poll_data

          expect(context).to have_received(:write_user_data).with(parsed_json)
        end

        it 'returns the parsed JSON data' do
          result = context.poll_data

          expect(result).to eq(parsed_json)
        end
      end

      context 'when plugin is configured for a POST request' do
        before do
          allow(faraday_connection).to receive(:post).and_return(faraday_get_response)
          allow(context.config.plugin).to receive(:polling_verb)
            .and_return('POST')
        end

        it 'calls write_user_data with the parsed JSON from the response' do
          context.poll_data

          expect(context).to have_received(:write_user_data).with(parsed_json)
        end

        it 'returns the parsed JSON data' do
          result = context.poll_data

          expect(result).to eq(parsed_json)
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
