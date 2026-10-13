# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/firefox_driver'

RSpec.describe TRMNLP::FirefoxDriver do
  describe '.build' do
    let(:driver) { instance_double(Selenium::WebDriver::Driver, quit: nil, manage: manage) }
    let(:manage) { instance_double(Selenium::WebDriver::Manager, window: instance_double(Selenium::WebDriver::Window, maximize: nil)) }
    let(:exit_hooks) { [] }

    before do
      allow(Selenium::WebDriver).to receive(:for).and_return(driver)
      allow(described_class).to receive(:at_exit) { |&hook| exit_hooks << hook }
    end

    it 'quits the driver at exit' do
      described_class.build
      exit_hooks.each(&:call)

      expect(driver).to have_received(:quit)
    end

    it 'ignores a driver that has already quit' do
      allow(driver).to receive(:quit).and_raise(Errno::ECONNREFUSED)
      described_class.build

      expect { exit_hooks.each(&:call) }.not_to raise_error
    end
  end

  describe '.options' do
    subject(:options) { described_class.options }

    it 'runs Firefox headless with web security disabled' do
      expect(options.args).to include('--headless', '--disable-web-security')
    end

    it 'opens a WebDriver BiDi connection, which sets viewports narrower than a window can be' do
      expect(options.web_socket_url).to be(true)
    end
  end
end
