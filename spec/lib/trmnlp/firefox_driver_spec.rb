# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/firefox_driver'

RSpec.describe TRMNLP::FirefoxDriver do
  describe '.options' do
    subject(:options) { described_class.options }

    it 'runs Firefox headless with web security disabled' do
      expect(options.args).to include('--headless', '--disable-web-security')
    end

    it 'disables subpixel antialiasing so 1-bit quantization stays clean' do
      expect(options.prefs).to include('gfx.text.disable-aa' => true,
                                       'gfx.text.subpixel-position.force-disabled' => true)
    end
  end
end
