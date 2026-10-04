# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/testing/inline_stylesheets'

RSpec.describe TRMNLP::Testing::InlineStylesheets do
  before { described_class.cache.clear }

  let(:html) { '<head><link rel="stylesheet" href="https://cdn.test/css/plugins.css" /><title>t</title></head>' }

  context 'when the stylesheet answers' do
    before do
      stub_request(:get, 'https://cdn.test/css/plugins.css')
        .to_return(body: '@font-face{src:url("../fonts/a.woff2")}.x{background:url(data:image/png;base64,AA)}')
    end

    it 'puts its rules in the page, so they apply before any script runs' do
      expect(described_class.call(html)).to include('<style data-href="https://cdn.test/css/plugins.css">')
    end

    it 'resolves relative urls against the stylesheet' do
      expect(described_class.call(html)).to include('url("https://cdn.test/fonts/a.woff2")')
    end

    it 'leaves data urls alone' do
      expect(described_class.call(html)).to include('url(data:image/png;base64,AA)')
    end

    it "leaves a link inside a script's string alone, so the script still parses" do
      fallback = %(<script>document.write('<link rel="stylesheet" href="https://cdn.test/css/plugins.css">')</script>)

      expect(described_class.call(fallback)).to eq(fallback)
    end

    it 'fetches a stylesheet once per run' do
      2.times { described_class.call(html) }

      expect(a_request(:get, 'https://cdn.test/css/plugins.css')).to have_been_made.once
    end
  end

  context 'when the stylesheet cannot be fetched' do
    before { stub_request(:get, 'https://cdn.test/css/plugins.css').to_return(status: 404) }

    it 'keeps the link' do
      expect(described_class.call(html)).to eq(html)
    end
  end
end
