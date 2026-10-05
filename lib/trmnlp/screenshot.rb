# frozen_string_literal: true

require 'selenium-webdriver'
require 'tempfile'

require_relative 'errors'

module TRMNLP
  class Screenshot
    # TRMNL's Converter::Html waits for these flags, longer for a map, then captures what is drawn.
    READINESS_TIMEOUT_SECONDS = 5
    READINESS_TIMEOUT_WITH_MAPS_SECONDS = 12
    MAPS_DOCUMENT_PATTERN = %r{TRMNLMaps\.[a-z]|maplibre-gl(?:\.js|\.css|[/@]\d)}
    READINESS_CHECK_SCRIPT = <<~JS
      return document.readyState === 'complete' && window.TRMNL_PLUGINS_READY === true &&
             window.TRMNL_HIGHCHARTS_DONE === true && window.TRMNL_CHILD_DITHER_DONE !== false
    JS
    # A font file that never arrives would keep the page waiting until WebDriver's own 30 second limit.
    FONTS_TIMEOUT_SECONDS = 10
    FONTS_LOADED_SCRIPT = "return !document.fonts || document.fonts.status === 'loaded'"
    FONTS_LOADING_SCRIPT =
      "return [...document.fonts].filter((font) => font.status === 'loading').map((font) => font.family)"
    # Stops timers and animation callbacks from changing the page mid-capture. A window numbers its timeouts
    # and intervals upward from one counter, so a new timer's id is the highest there is to clear.
    FREEZE_TIMERS = <<~JS
      const noop = () => 0;
      const newest = window.setTimeout(noop, 0);
      window.setTimeout = window.setInterval = noop;
      window.requestAnimationFrame = noop;
      if (window.requestIdleCallback) window.requestIdleCallback = noop;
      for (let i = typeof newest === 'number' ? newest : 100000; i >= 0; i--) { window.clearTimeout(i); window.clearInterval(i); }
      if (window.ResizeObserver) window.ResizeObserver.prototype.observe = noop;
      if (window.MutationObserver) window.MutationObserver.prototype.observe = noop;
      window.onresize = null;
    JS

    def initialize(pool:, viewport_timeout: 5, fonts_timeout: FONTS_TIMEOUT_SECONDS)
      @pool = pool
      @viewport_timeout = viewport_timeout
      @fonts_timeout = fonts_timeout
    end

    def call(html:, width:, height:)
      attempts = 0

      begin
        @pool.with_driver { |driver| render(driver, html, width, height) }
      rescue Selenium::WebDriver::Error::TimeoutError,
             Selenium::WebDriver::Error::WebDriverError
        attempts += 1
        retry if attempts <= 1
        raise
      end
    end

    # Loads html into driver at width x height and waits until TRMNL would capture it, and until wait_for
    # (a JavaScript expression) is true when given: a page still drawing would be stopped by the frozen timers.
    # rubocop:disable-next Metrics/ParameterLists -- the page, its size, and what to wait for
    # url: an address that serves html, opened in place of writing html into a blank page.
    def show(driver, html, width, height, wait_for: nil, wait_for_timeout: READINESS_TIMEOUT_SECONDS, url: nil)
      resize(driver, width, height)
      load_page(driver, html, url:) { wait_for_expression(driver, wait_for, wait_for_timeout) if wait_for }
    end

    def capture(driver)
      file = Tempfile.new(['screenshot', '.png'])
      driver.save_screenshot(file.path)
      file.close
      file
    end

    private

    def render(driver, html, width, height)
      show(driver, html, width, height)
      capture(driver)
    end

    def resize(driver, width, height)
      return if viewport(driver) == [width, height]

      set_viewport(driver, width, height)
      wait_for_viewport(driver, width, height)
    end

    # The page's viewport, not the window: Firefox will not size a window under about 500px, as an OG in portrait.
    def set_viewport(driver, width, height)
      driver.bidi.send_cmd('browsingContext.setViewport', context: driver.window_handle, viewport: { width:, height: })
    end

    # NOTE: A cold Firefox — e.g. the first render after the container boots —
    # applies a resize lazily. The old fixed sleep raced that reflow and
    # clipped the first screenshot short (800x433 instead of 800x480). Poll the
    # real viewport instead, re-applying the size until it lands.
    def wait_for_viewport(driver, width, height)
      Selenium::WebDriver::Wait.new(timeout: @viewport_timeout, interval: 0.01).until do
        next true if viewport(driver) == [width, height]

        set_viewport(driver, width, height)
        false
      end
    rescue Selenium::WebDriver::Error::TimeoutError
      actual_width, actual_height = viewport(driver)
      raise RenderError, "Could not render at #{width}x#{height}: the viewport stayed #{actual_width}x#{actual_height}"
    end

    def viewport(driver)
      driver.execute_script('return [window.innerWidth, window.innerHeight]')
    end

    # A font that stalls is usually a dropped connection, so the page is loaded once more before giving up.
    def load_page(driver, html, url: nil, &)
      attempts = 0
      begin
        open_page(driver, html, url, &)
      rescue Selenium::WebDriver::Error::TimeoutError
        retry if (attempts += 1) <= 1
        loading = driver.execute_script(FONTS_LOADING_SCRIPT).uniq.join(', ')
        raise RenderError, "The page's fonts did not load within #{@fonts_timeout}s: #{loading}"
      end

      driver.execute_script(<<~JS)
        document.documentElement.style.overflow = 'hidden';
        document.body.style.overflow = 'hidden';
      JS
      driver.execute_script(FREEZE_TIMERS)
    end

    def open_page(driver, html, url)
      url ? driver.navigate.to(url) : write_page(driver, html)

      wait_until_ready(driver, html)
      yield if block_given?
      Selenium::WebDriver::Wait.new(timeout: @fonts_timeout, interval: 0.05)
                               .until { driver.execute_script(FONTS_LOADED_SCRIPT) }
    end

    def write_page(driver, html)
      driver.navigate.to('about:blank')

      driver.execute_script(<<~JS, html)
        document.open();
        document.write(arguments[0]);
        document.close();
      JS
    end

    def wait_for_expression(driver, expression, timeout)
      Selenium::WebDriver::Wait.new(timeout:, interval: 0.05).until { driver.execute_script("return !!(#{expression});") }
    rescue Selenium::WebDriver::Error::TimeoutError
      raise RenderError, "The page did not reach #{expression} within #{timeout}s"
    end

    def wait_until_ready(driver, html)
      timeout = html.match?(MAPS_DOCUMENT_PATTERN) ? READINESS_TIMEOUT_WITH_MAPS_SECONDS : READINESS_TIMEOUT_SECONDS
      Selenium::WebDriver::Wait.new(timeout:, interval: 0.05).until { driver.execute_script(READINESS_CHECK_SCRIPT) }
    rescue Selenium::WebDriver::Error::TimeoutError
      nil
    end
  end
end
