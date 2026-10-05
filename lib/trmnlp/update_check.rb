# frozen_string_literal: true

require 'faraday'
require 'json'
require_relative 'reporter'
require_relative 'version'

module TRMNLP
  class UpdateCheck
    ENDPOINT = 'https://rubygems.org/api/v1/gems/trmnl_preview.json'
    TIMEOUT = 2

    def initialize(reporter: Reporter.new(stream: $stderr))
      @reporter = reporter
    end

    def call
      latest = latest_version
      return unless latest && latest > Gem::Version.new(VERSION)

      reporter.info("trmnl_preview #{latest} is available (installed: #{VERSION}).")
      reporter.info(update_guidance)
    end

    private

    attr_reader :reporter

    def latest_version
      response = Faraday.get(ENDPOINT) do |request|
        request.options.open_timeout = TIMEOUT
        request.options.timeout = TIMEOUT
      end
      parse_version(response.body) if response.success?
    rescue Faraday::Error, JSON::ParserError, ArgumentError
      nil
    end

    def parse_version(body)
      data = JSON.parse(body)
      value = data['version'] if data.is_a?(Hash)
      return unless value.is_a?(String) && !value.empty? && Gem::Version.correct?(value)

      version = Gem::Version.new(value)
      version unless version.prerelease?
    end

    def update_guidance
      return 'Update with: gem update trmnl_preview' if ENV['BUNDLE_GEMFILE'].to_s.empty?

      'Update the trmnl_preview constraint in your Gemfile if needed, then run: bundle update trmnl_preview'
    end
  end
end
