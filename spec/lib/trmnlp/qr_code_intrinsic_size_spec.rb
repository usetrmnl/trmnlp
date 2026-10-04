# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/qr_code_intrinsic_size'

RSpec.describe TRMNLP::QrCodeIntrinsicSize do
  subject(:svg_tag) { Liquid::Template.parse(markup, environment: TRMNL::Liquid.new).render[/<svg[^>]*>/] }

  context 'with the default responsive view' do
    let(:markup) { '{{ "Test" | qr_code }}' }

    it 'gives the code its own size and lets it shrink, like the hosted service' do
      expect(svg_tag).to include('width="231" height="231" style="max-width:100%;height:auto"')
    end
  end

  context 'with the fixed view' do
    let(:markup) { '{{ "Test" | qr_code: 11, "", "fixed" }}' }

    it 'leaves the size trmnl-liquid gave it' do
      expect(svg_tag).not_to include('max-width')
    end
  end
end
