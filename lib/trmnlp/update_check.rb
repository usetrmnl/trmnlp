# frozen_string_literal: true

require 'faraday'
require 'json'
require_relative 'reporter'
require_relative 'version'

module TRMNLP
  # Tells the user when RubyGems has a newer trmnl_preview. The answer is
  # cached for a day so routine commands do not wait on the network; a
  # failed lookup is cached too, so an offline run stalls at most once a day.
  class UpdateCheck
    ENDPOINT = 'https://rubygems.org/api/v1/gems/trmnl_preview.json'
    TIMEOUT = 2
    CACHE_TTL = 24 * 60 * 60
    DISABLE_ENV_KEY = 'TRMNLP_NO_UPDATE_NOTIFIER'

    def self.disabled? = !ENV[DISABLE_ENV_KEY].to_s.empty?

    def initialize(cache_path, reporter: Reporter.new(stream: $stderr))
      @cache_path = Pathname.new(cache_path)
      @reporter = reporter
    end

    # Reports a newer stable release. fresh: asks RubyGems now instead of
    # trusting a cached answer from the last day.
    def call(fresh: false)
      latest = fresh ? refresh : cached
      return unless latest && latest > Gem::Version.new(VERSION)

      reporter.info("trmnl_preview #{latest} is available (installed: #{VERSION}).")
      reporter.info(update_guidance)
    end

    private

    attr_reader :cache_path, :reporter

    def cached
      cache = read_cache
      return version_from(cache['version']) if cache && Time.now.to_i - cache['checked_at'] < CACHE_TTL

      refresh
    end

    def refresh
      latest = fetch_latest
      write_cache(latest)
      latest
    end

    def read_cache
      data = JSON.parse(cache_path.read)
      data if data.is_a?(Hash) && data['checked_at'].is_a?(Integer)
    rescue SystemCallError, JSON::ParserError
      nil
    end

    def write_cache(latest)
      cache_path.dirname.mkpath
      cache_path.write(JSON.generate(checked_at: Time.now.to_i, version: latest&.to_s))
    rescue SystemCallError
      nil
    end

    def fetch_latest
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
      version_from(data['version']) if data.is_a?(Hash)
    end

    def version_from(value)
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
