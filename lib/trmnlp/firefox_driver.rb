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
      Selenium::WebDriver::Firefox::Options.new(web_socket_url: true).tap do |opts|
        opts.add_argument('--headless')
        opts.add_argument('--disable-web-security')
      end
    end
  end
end
