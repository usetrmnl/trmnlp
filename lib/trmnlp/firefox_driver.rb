# frozen_string_literal: true

require 'selenium-webdriver'

module TRMNLP
  # Builds the headless Firefox driver that screenshots rendered plugins.
  # Shared by `trmnlp serve` (the PNG preview route) and `trmnlp build --png`.
  module FirefoxDriver
    module_function

    def build
      Selenium::WebDriver.for(:firefox, options:).tap do |driver|
        # Exit hooks run newest first, so this quits Firefox before Selenium's hook stops geckodriver and orphans it.
        at_exit { quit(driver) }
        driver.manage.window.maximize
      end
    end

    def quit(driver)
      driver.quit
    rescue StandardError
      nil
    end

    def options
      Selenium::WebDriver::Firefox::Options.new(web_socket_url: true).tap do |opts|
        opts.add_argument('--headless')
        opts.add_argument('--disable-web-security')
        # A page trmnlp test serves from 127.0.0.1 gets no storage, cookies or Referer, as on TRMNL's about:blank.
        opts.add_preference('network.cookie.cookieBehavior', 2)
        opts.add_preference('network.http.sendRefererHeader', 0)
      end
    end
  end
end
