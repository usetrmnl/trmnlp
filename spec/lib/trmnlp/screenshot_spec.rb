# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/screenshot'

RSpec.describe TRMNLP::Screenshot do
  subject(:screenshot) { described_class.new(pool:) }

  let(:driver) { FakeDriver.new }
  let(:pool) { FakePool.new(driver) }

  class FakeDriver
    attr_reader :scripts_run, :window_size, :screenshot_path, :navigated_to, :size_set_count
    attr_accessor :script_errors, :viewport_overrides

    def initialize
      @scripts_run = []
      @navigated_to = []
      @script_errors = []
      @viewport_overrides = []
      @size_set_count = 0
    end

    def execute_script(script, *_args)
      raise @script_errors.shift if @script_errors.any?

      @scripts_run << script
      return { 'width' => 10, 'height' => 20 } if script.include?('outerWidth')
      return next_viewport if script.include?('innerWidth')

      'complete' if script.include?('readyState')
    end

    def manage = self
    def window = self

    def size=(dim)
      @size_set_count += 1
      @window_size = dim
    end

    def navigate = NavigateFake.new(self)
    def save_screenshot(path) = @screenshot_path = path

    private

    # A real browser's viewport is the window minus the chrome borders
    # (10x20 above). Queue `viewport_overrides` to simulate a cold Firefox
    # reporting a not-yet-settled size before the resize lands.
    def next_viewport
      return @viewport_overrides.shift if @viewport_overrides.any?

      [@window_size.width - 10, @window_size.height - 20]
    end
  end

  class NavigateFake
    def initialize(driver) = @driver = driver
    def to(url) = @driver.navigated_to << url
  end

  class FakePool
    def initialize(driver)
      @driver = driver
      @yield_count = 0
      @raise_on = []
    end

    attr_accessor :raise_on, :yield_count

    def with_driver
      @yield_count += 1
      raise @raise_on.shift if @raise_on.any?

      yield @driver
    end
  end

  describe '#call' do
    let(:result) { screenshot.call(html: '<p>hi</p>', width: 800, height: 480) }

    it 'returns a Tempfile that received the screenshot' do
      expect(result).to be_a(Tempfile)
      expect(driver.screenshot_path).to eq(result.path)
    end

    it 'resizes the driver window to width+borders by height+borders' do
      result
      expect(driver.window_size.width).to eq(810)
      expect(driver.window_size.height).to eq(500)
    end

    it 're-applies the window size until the viewport reports the requested dimensions' do
      driver.viewport_overrides = [[800, 433], [800, 433]]
      result
      expect(driver.size_set_count).to eq(3)
    end

    it 'navigates to about:blank before loading the page' do
      result
      expect(driver.navigated_to).to eq(['about:blank'])
    end

    it 'retries once on Selenium WebDriverError' do
      pool.raise_on = [Selenium::WebDriver::Error::WebDriverError.new('flake')]
      result
      expect(pool.yield_count).to eq(2)
    end

    it 'raises after two failed attempts' do
      pool.raise_on = Array.new(2) { Selenium::WebDriver::Error::WebDriverError.new('flake') }
      expect { result }.to raise_error(Selenium::WebDriver::Error::WebDriverError)
    end
  end
end
