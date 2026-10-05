# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/testing/screen'

RSpec.describe TRMNLP::Testing::Screen do
  subject(:screen) { described_class.new(html: '<p>hi</p>', device:, view: 'full', browser:, result: nil) }

  let(:device) { Struct.new(:name, :width, :height).new('og_png', 800, 480) }
  let(:browser) do
    Class.new do
      attr_reader :loaded, :captures

      def initialize = @captures = 0
      def load(screen) = @loaded = screen
      def on(_screen) = '<html><body><p>hi</p></body></html>'

      def capture(_screen)
        @captures += 1
        '/tmp/screen.png'
      end
    end.new
  end

  it 'loads its page, and reads what is drawn' do
    expect([screen, browser.loaded]).to match([have_text('hi'), screen])
  end

  it 'takes no picture for a test that only reads the page' do
    screen.has_text?('hi')

    expect(browser.captures).to eq(0)
  end

  it 'takes the picture when it is asked for, once' do
    paths = [screen.png_path, screen.png_path]

    expect([paths, browser.captures]).to eq([['/tmp/screen.png', '/tmp/screen.png'], 1])
  end
end
