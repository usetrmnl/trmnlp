# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/qr_code'

RSpec.describe TRMNLP::QrCode do
  subject(:svg) { Liquid::Template.parse(markup, environment: TRMNL::Liquid.new).render }

  context 'with the default responsive view' do
    let(:markup) { '{{ "Test" | qr_code }}' }

    it 'keeps the size the code had without a border, and lets it shrink' do
      expect(svg).to include('width="231" height="231" style="max-width:100%;height:auto"')
    end

    it 'fits a border four modules wide inside that size' do
      expect(svg).to include('viewBox="-44 -44 319 319"')
    end

    it 'paints the border white, so the code scans on a dark page' do
      expect(svg).to include('<rect width="319" height="319" x="-44" y="-44" fill="#fff"/>')
    end
  end

  context 'with the fixed view' do
    let(:markup) { '{{ "Test" | qr_code: 5, "", "fixed" }}' }

    it 'keeps the fixed size' do
      expect(svg).to include('width="105" height="105" viewBox="-20 -20 145 145"')
    end

    it 'does not let it shrink' do
      expect(svg).not_to include('max-width')
    end
  end
end
