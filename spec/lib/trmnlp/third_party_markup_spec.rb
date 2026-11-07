# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::ThirdPartyMarkup do
  def reply(status, body) = [Struct.new(:status, :body).new(status, body), nil]

  subject(:third_party_markup) do
    described_class.new(settings:, outbound_request:, trmnl_variables: lambda { |device|
      { 'trmnl' => { 'device' => device } }
    })
  end

  let(:settings) { { 'plugin_markup_url' => 'https://plugin.test/markup', 'access_token' => 'token-1', 'user_uuid' => 'u-1' } }
  let(:outbound_request) { instance_double(TRMNLP::OutboundRequest, call: reply(200, JSON.generate(answer))) }
  let(:answer) do
    { 'markup' => '<p>{{ temp }}</p>', 'markup_quadrant' => '<b>q</b>', 'merge_variables' => { 'temp' => 12 } }
  end

  describe '#call' do
    it 'posts the user uuid and the trmnl variables for the device, form-encoded, with the access token' do
      third_party_markup.call(device: { 'width' => 800 })

      expect(outbound_request).to have_received(:call).with(
        'POST', 'https://plugin.test/markup',
        headers: { 'Content-Type' => 'application/x-www-form-urlencoded', 'Authorization' => 'Bearer token-1' },
        body: 'user_uuid=u-1&trmnl%5Bdevice%5D%5Bwidth%5D=800'
      )
    end

    it 'answers each view with its markup and the merge variables' do
      expect(third_party_markup.call(device: {})).to eq(
        'full' => '<p>{{ temp }}</p>', 'quadrant' => '<b>q</b>', 'half_horizontal' => nil, 'half_vertical' => nil,
        'shared' => nil, 'merge_variables' => { 'temp' => 12 }
      )
    end

    it 'answers empty merge variables when the plugin sends none, as TRMNL does' do
      answer.delete('merge_variables')

      expect(third_party_markup.call(device: {})['merge_variables']).to eq({})
    end

    context 'without an access token or a user uuid' do
      let(:settings) { { 'plugin_markup_url' => 'https://plugin.test/markup' } }

      it 'sends no Authorization header and a stand-in uuid' do
        third_party_markup.call(device: {})

        expect(outbound_request).to have_received(:call).with(
          'POST', anything, headers: { 'Content-Type' => 'application/x-www-form-urlencoded' },
                            body: "user_uuid=#{described_class::STAND_IN_USER_UUID}"
        )
      end
    end

    it 'answers the shared markup the plugin sends' do
      answer['shared'] = '<style>.a{}</style>'

      expect(third_party_markup.call(device: {})['shared']).to eq('<style>.a{}</style>')
    end

    it 'asks the plugin once per device, as TRMNL asks once per refresh and draws every view from the answer' do
      2.times { third_party_markup.call(device: { 'width' => 800 }) }
      third_party_markup.call(device: { 'width' => 1872 })

      expect(outbound_request).to have_received(:call).twice
    end

    it 'asks again after a refresh' do
      third_party_markup.call(device: {})
      third_party_markup.refresh
      third_party_markup.call(device: {})

      expect(outbound_request).to have_received(:call).twice
    end

    it 'answers the merge variables of a new refresh, for the preview page' do
      third_party_markup.call(device: {})

      expect(third_party_markup.preview_merge_variables(device: {})).to eq('temp' => 12)
      expect(outbound_request).to have_received(:call).twice
    end

    it 'answers why the plugin could not be asked, for the preview page' do
      allow(outbound_request).to receive(:call).and_return([nil, 'no answer'])

      expect(third_party_markup.preview_merge_variables(device: {}))
        .to eq('error' => 'Plugin markup unavailable: no answer')
    end

    context 'when plugin_markup_url reads an environment variable that is not set' do
      let(:settings) { { 'plugin_markup_url' => ' ' } }

      it 'says so instead of sending the request' do
        expect { third_party_markup.call(device: {}) }.to raise_error(
          TRMNLP::RenderError, 'Plugin markup unavailable: plugin_markup_url in .trmnlp.yml is empty, ' \
                               'so an environment variable it reads is probably not set'
        )
      end
    end

    it 'names an empty answer' do
      allow(outbound_request).to receive(:call).and_return(reply(200, ''))

      expect { third_party_markup.call(device: {}) }
        .to raise_error(TRMNLP::RenderError, 'Plugin markup unavailable: the host replied 200 with an empty body')
    end

    it 'reads JSON that starts with a byte order mark, as TRMNL does' do
      allow(outbound_request).to receive(:call).and_return(reply(200, "\uFEFF{\"markup\": \"<b>\"}"))

      expect(third_party_markup.call(device: {})['full']).to eq('<b>')
    end

    it 'raises a render error with the status and body when the plugin does not answer 2xx' do
      allow(outbound_request).to receive(:call).and_return(reply(401, '{"error":"bad token"}'))

      expect { third_party_markup.call(device: {}) }
        .to raise_error(TRMNLP::RenderError, 'Plugin markup unavailable: the host replied 401: {"error":"bad token"}')
    end

    it 'raises a render error when merge_variables is not a JSON object' do
      answer['merge_variables'] = [1]

      expect { third_party_markup.call(device: {}) }
        .to raise_error(TRMNLP::RenderError, 'Plugin markup unusable: merge_variables must be a JSON object, not [1]')
    end

    it 'raises a render error when a markup is not a string' do
      answer['markup_quadrant'] = 42

      expect { third_party_markup.call(device: {}) }
        .to raise_error(TRMNLP::RenderError, 'Plugin markup unusable: markup_quadrant must be a string, not 42')
    end

    it 'raises a render error naming why the request failed' do
      allow(outbound_request).to receive(:call).and_return([nil, 'the host replied 500'])

      expect { third_party_markup.call(device: {}) }
        .to raise_error(TRMNLP::RenderError, 'Plugin markup unavailable: the host replied 500')
    end

    it 'raises a render error when the answer is not a JSON object' do
      allow(outbound_request).to receive(:call).and_return(reply(200, '<html>Sign in'))

      expect { third_party_markup.call(device: {}) }
        .to raise_error(TRMNLP::RenderError,
                        'Plugin markup unavailable: the host replied 200 with no JSON object: <html>Sign in')
    end
  end
end
