# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::Context do
  describe '#oauth_session' do
    subject(:context) { described_class.new(File.join(__dir__, '../../fixtures')) }

    it 'builds an OAuth session' do
      expect(context.oauth_session).to be_a(TRMNLP::OAuth::Session)
    end

    it 'memoizes the session' do
      expect(context.oauth_session).to be(context.oauth_session)
    end
  end

  describe '#renderer' do
    context 'with a third_party block in .trmnlp.yml' do
      subject(:context) { described_class.new(dir, outbound_request:) }

      let(:dir) do
        Dir.mktmpdir.tap do |dir|
          File.write(File.join(dir, '.trmnlp.yml'), <<~YAML)
            third_party:
              plugin_markup_url: https://plugin.test/markup
              access_token: '{{ env.HOME }}'
          YAML
        end
      end
      let(:answer) do
        Struct.new(:status, :body).new(200, '{"markup": "<p>{{ temp }}</p>", "merge_variables": {"temp": 7}}')
      end
      let(:outbound_request) { instance_double(TRMNLP::OutboundRequest, call: [answer, nil]) }

      it "draws each view from the plugin's markup url" do
        expect(context.renderer.render_full_page('full', width: 800)).to include('<p>7</p>')
      end

      it 'posts the trmnl variables of the device being drawn, with the token read from the environment' do
        context.renderer.render_full_page('full', width: 1872)

        expect(outbound_request).to have_received(:call).with(
          'POST', 'https://plugin.test/markup',
          headers: hash_including('Authorization' => "Bearer #{Dir.home}"),
          body: include('trmnl%5Bdevice%5D%5Bwidth%5D=1872')
        )
      end
    end
  end

  describe '#validate!' do
    context 'when the directory is not a plugin' do
      subject(:context) { described_class.new('/tmp') }

      it 'raises NotAPlugin' do
        expect { context.validate! }.to raise_error(TRMNLP::NotAPlugin)
      end
    end

    context 'when the directory is a plugin' do
      subject(:context) { described_class.new(File.join(__dir__, '../../fixtures')) }

      it 'returns without raising' do
        expect { context.validate! }.not_to raise_error
      end
    end
  end
end
