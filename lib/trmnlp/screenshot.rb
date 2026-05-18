# frozen_string_literal: true

require 'selenium-webdriver'
require 'tempfile'

require_relative 'errors'

module TRMNLP
  class Screenshot
    def initialize(pool:, viewport_timeout: 5)
      @pool = pool
      @viewport_timeout = viewport_timeout
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

    private

    def render(driver, html, width, height)
      resize(driver, width, height)
      load_page(driver, html)
      capture(driver)
    end

    def resize(driver, width, height)
      apply_window_size(driver, width, height)
      wait_for_viewport(driver, width, height)
    end

    def apply_window_size(driver, width, height)
      borders = driver.execute_script(<<~JS)
        return {
          width: window.outerWidth - window.innerWidth,
          height: window.outerHeight - window.innerHeight
        }
      JS

      dim = Selenium::WebDriver::Dimension.new(width + borders['width'], height + borders['height'])
      driver.manage.window.size = dim
    end

    # NOTE: A cold Firefox — e.g. the first render after the container boots —
    # applies a window resize lazily. The old fixed sleep raced that reflow and
    # clipped the first screenshot short (800x433 instead of 800x480). Poll the
    # real viewport instead, re-applying the size until it lands. A width the
    # browser refuses to honour (below its ~500px window minimum) never settles;
    # that surfaces as a clear RenderError rather than an opaque, retried timeout.
    def wait_for_viewport(driver, width, height)
      Selenium::WebDriver::Wait.new(timeout: @viewport_timeout, interval: 0.1).until do
        next true if viewport(driver) == [width, height]

        apply_window_size(driver, width, height)
        false
      end
    rescue Selenium::WebDriver::Error::TimeoutError
      raise RenderError, viewport_clamp_message(driver, width, height)
    end

    def viewport_clamp_message(driver, width, height)
      actual_width, actual_height = viewport(driver)
      "Could not render at #{width}x#{height}: the browser clamped the viewport " \
        "to #{actual_width}x#{actual_height}. PNG rendering needs a width of " \
        'roughly 500px or more — headless Firefox will not size its window narrower.'
    end

    def viewport(driver)
      driver.execute_script('return [window.innerWidth, window.innerHeight]')
    end

    def load_page(driver, html)
      driver.navigate.to('about:blank')

      driver.execute_script(<<~JS, html)
        document.open();
        document.write(arguments[0]);
        document.close();
      JS

      Selenium::WebDriver::Wait.new(timeout: 5).until do
        driver.execute_script('return document.readyState') == 'complete'
      end

      driver.execute_script('return document.fonts && document.fonts.ready')

      driver.execute_script(<<~JS)
        document.documentElement.style.overflow = 'hidden';
        document.body.style.overflow = 'hidden';
      JS
    end

    def capture(driver)
      file = Tempfile.new(['screenshot', '.png'])
      driver.save_screenshot(file.path)
      file.close
      file
    end
  end
end
