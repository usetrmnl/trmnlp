# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/no_external_qr_codes'

RSpec.describe TRMNLP::Lint::Checks::NoExternalQrCodes do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }

  describe '#issues' do
    shared_examples 'a markup with an external QR code' do
      it 'reports the issue' do
        expect(check.issues).to contain_exactly(hash_including(message: described_class::MESSAGE))
      end
    end

    shared_examples 'a markup without an external QR code' do
      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    %w[
      https://api.qrserver.com/v1/create-qr-code/?data=hello
      https://goqr.me/api/qr?data=hello
      https://qrcode.tec-it.com/API/QRCode?data=hello
      https://api.qrcode-monkey.com/qr/custom?data=hello
      //QUICKCHART.IO/qr?text=hello
    ].each do |url|
      context "when an img loads a code from #{url}" do
        let(:markup) { %(<img src="#{url}">) }

        it_behaves_like 'a markup with an external QR code'
      end
    end

    context 'when Liquid builds the generator URL' do
      let(:markup) { %(<img src="https://api.qrserver.com/v1/create-qr-code/?data={{ url | url_encode }}">) }

      it_behaves_like 'a markup with an external QR code'
    end

    context 'when a CSS background loads the code' do
      let(:markup) { %(<div style="background-image: url('https://quickchart.io/qr?text={{ url }}')"></div>) }

      it_behaves_like 'a markup with an external QR code'
    end

    context 'when a Google chart asks for cht=qr after a Liquid value' do
      let(:markup) { %(<img src="https://chart.googleapis.com/chart?chl={{ url }}&amp;cht=qr&amp;chs=200x200">) }

      it_behaves_like 'a markup with an external QR code'
    end

    context 'when a service that also draws charts draws a chart, not a QR code' do
      let :markup do
        <<~HTML
          <img src="https://quickchart.io/chart?c={type:'bar'}">
          <img src="https://chart.googleapis.com/chart?cht=p3&amp;chd=t:60,40">
        HTML
      end

      it_behaves_like 'a markup without an external QR code'
    end

    context 'when an image named qr is on the author host, not a QR generator' do
      let(:markup) { %(<img src="https://example.com/images/qr.png"><img src="https://myqrserver.com/code.png">) }

      it_behaves_like 'a markup without an external QR code'
    end

    context 'when the markup links to a generator without loading an image from it' do
      let(:markup) { %(<a href="https://goqr.me">Made with goqr.me</a>) }

      it_behaves_like 'a markup without an external QR code'
    end

    context 'when the markup uses the built-in qr_code filter' do
      let(:markup) { '<div>{{ url | qr_code }}</div>' }

      it_behaves_like 'a markup without an external QR code'
    end

    context 'when the markup has no images' do
      let(:markup) { '<div class="title">Hello</div>' }

      it_behaves_like 'a markup without an external QR code'
    end
  end
end
