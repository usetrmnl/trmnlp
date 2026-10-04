# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/screenshot'

RSpec.describe TRMNLP::Screenshot do
  subject(:screenshot) { described_class.new(pool:) }

  let(:driver) { FakeDriver.new }
  let(:pool) { FakePool.new(driver) }

  class FakeDriver
    attr_reader :scripts_run, :viewport_set, :screenshot_path, :navigated_to, :viewport_set_count
    attr_accessor :script_errors, :viewport_overrides, :readiness_answers

    def initialize
      @scripts_run = []
      @navigated_to = []
      @script_errors = []
      @viewport_overrides = []
      @viewport_set_count = 0
      @readiness_answers = []
    end

    def execute_script(script, *_args)
      raise @script_errors.shift if @script_errors.any?

      @scripts_run << script
      return next_viewport if script.include?('innerWidth')

      @readiness_answers.empty? || @readiness_answers.shift if script.include?('TRMNL_PLUGINS_READY')
    end

    def bidi = self
    def window_handle = 'context-1'

    def send_cmd(command, context:, viewport:)
      raise ArgumentError, command unless command == 'browsingContext.setViewport' && context == 'context-1'

      @viewport_set_count += 1
      @viewport_set = viewport
    end

    def navigate = NavigateFake.new(self)
    def save_screenshot(path) = @screenshot_path = path

    private

    # Queue `viewport_overrides` for a cold Firefox reporting a size before the new viewport lands.
    def next_viewport
      return @viewport_overrides.shift if @viewport_overrides.any?

      @viewport_set.values_at(:width, :height)
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

    it 'sets the viewport to the requested size through WebDriver BiDi' do
      result
      expect(driver.viewport_set).to eq(width: 800, height: 480)
    end

    it 're-applies the viewport until the page reports the requested dimensions' do
      driver.viewport_overrides = [[800, 433], [800, 433]]
      result
      expect(driver.viewport_set_count).to eq(3)
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

    it 'polls until the page signals TRMNL readiness' do
      driver.readiness_answers = [false, false, true]
      result
      expect(driver.scripts_run.count { |script| script.include?('TRMNL_PLUGINS_READY') }).to eq(3)
    end

    it 'freezes timers as the last step before capture' do
      result
      expect(driver.scripts_run.last).to include('requestAnimationFrame')
    end

    context 'when the page never signals readiness' do
      before do
        stub_const("#{described_class}::READINESS_TIMEOUT_SECONDS", 0.1)
        driver.readiness_answers = Array.new(1000, false)
      end

      it 'captures anyway' do
        expect(result.path).to eq(driver.screenshot_path)
      end
    end

    context 'when the page draws a map' do
      before { allow(Selenium::WebDriver::Wait).to receive(:new).and_call_original }

      it 'waits up to the longer maps readiness timeout' do
        screenshot.call(html: '<script>TRMNLMaps.create()</script>', width: 800, height: 480)
        expect(Selenium::WebDriver::Wait).to have_received(:new).with(hash_including(timeout: 12))
      end
    end

    context 'when the viewport never reaches the requested size' do
      subject(:screenshot) { described_class.new(pool:, viewport_timeout: 0.1) }

      before { driver.viewport_overrides = Array.new(1000, [500, 240]) }

      it 'raises a RenderError naming the requested and actual sizes' do
        expect { screenshot.call(html: '<p>hi</p>', width: 400, height: 240) }
          .to raise_error(TRMNLP::RenderError, /400x240.+500x240/)
      end
    end
  end
end
