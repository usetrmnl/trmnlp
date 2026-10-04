# frozen_string_literal: true

# Loaded by `trmnlp test`: gives each example `trmnl`, Capybara's matchers and trmnlp's own.
require 'capybara/rspec/matchers'
require 'rspec/core'
require 'rspec/expectations'

require_relative '../../trmnlp'
require_relative '../browser_pool'
require_relative '../firefox_driver'
require_relative 'browser'
require_relative 'certificate_authority'
require_relative 'plugin'
require_relative 'snapshot'

module TRMNLP
  module Testing
    PLUGIN_DIR_ENV_KEY = 'TRMNLP_PLUGIN_DIR'

    def self.plugin_dir = ENV.fetch(PLUGIN_DIR_ENV_KEY, Dir.pwd)

    def self.authority
      @authority ||= CertificateAuthority.new.tap { |authority| at_exit { authority.remove } }
    end

    def self.browser_pool
      @browser_pool ||= BrowserPool.new(driver_factory: FirefoxDriver.method(:build), max_size: 1)
    end

    module Helpers
      def trmnl = @trmnl ||= Plugin.new(Testing.plugin_dir, browser: trmnl_browser, authority: Testing.authority)

      def trmnl_browser = @trmnl_browser ||= Browser.new(pool: Testing.browser_pool)
    end
  end
end

RSpec::Matchers.define :have_no_overflow do
  match { |screen| screen.overflowing.empty? }
  failure_message do |screen|
    "expected nothing to overflow on #{screen.inspect}, but: #{screen.overflowing.join(', ')}"
  end
end

# TRMNL gives a transform 5 seconds and 128 MB (help.trmnl.com, Serverless).
RSpec::Matchers.define :stay_within_serverless_limits do
  match { |run| run.duration_ms.to_i <= 5000 && run.max_memory_mb.to_f <= 128 }
  failure_message do |run|
    "expected the transform to stay within 5000 ms and 128 MB, but it took #{run.duration_ms} ms " \
      "and #{run.max_memory_mb} MB"
  end
end

RSpec::Matchers.define :have_no_problems do
  match { |screen| screen.problems.empty? }
  failure_message { |screen| "expected no problems on #{screen.inspect}, but: #{screen.problems.join('; ')}" }
end

RSpec::Matchers.define :fit_image_size_limit do
  match { |screen| screen.png_bytes.bytesize <= screen.device.image_size_limit.to_i }
  failure_message do |screen|
    "expected the #{screen.device.name} PNG to fit #{screen.device.image_size_limit} bytes, " \
      "but it is #{screen.png_bytes.bytesize}"
  end
end

RSpec::Matchers.define :match_snapshot do |name = nil|
  match do |screen|
    example = RSpec.current_example
    name ||= [example.full_description, screen.device.name, screen.view].join(' ').downcase.gsub(/[^a-z0-9]+/, '-')
    dir = File.join(TRMNLP::Testing.plugin_dir, 'tests', 'snapshots')
    @mismatch = TRMNLP::Testing::Snapshot.new(screen, name:, dir:).mismatch
    @mismatch.nil?
  end
  failure_message { @mismatch }
end

RSpec.configure do |config|
  config.include Capybara::RSpecMatchers
  config.include TRMNLP::Testing::Helpers
  config.after { @trmnl_browser&.release }
end
