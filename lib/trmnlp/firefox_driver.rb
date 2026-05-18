# frozen_string_literal: true

require 'selenium-webdriver'

module TRMNLP
  # Builds the headless Firefox driver that screenshots rendered plugins.
  # Shared by `trmnlp serve` (the PNG preview route) and `trmnlp build --png`.
  module FirefoxDriver
    module_function

    def build
      Selenium::WebDriver.for(:firefox, options:).tap do |driver|
        driver.manage.window.maximize
      end
    end

    def options
      Selenium::WebDriver::Firefox::Options.new.tap do |opts|
        opts.add_argument('--headless')
        opts.add_argument('--disable-web-security')
        # Subpixel antialiasing colour-fringes badly when quantized to 1-bit e-ink.
        opts.add_preference('gfx.text.disable-aa', true)
        opts.add_preference('gfx.text.subpixel-position.force-disabled', true)
      end
    end
  end
end
