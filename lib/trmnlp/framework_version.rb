# frozen_string_literal: true

require 'yaml'

module TRMNLP
  # Represents a TRMNL design-system framework version, so plugins can
  # pin (or float to "latest") the CSS/JS bundle they render against,
  # both in production and locally.
  class FrameworkVersion
    include Comparable

    DEFAULT_ASSET_HOST = 'https://trmnl.com'
    DATA_PATH = File.expand_path('../../db/data/framework_versions.yml', __dir__)

    attr_reader :number

    def self.config = @config ||= YAML.load_file(DATA_PATH).freeze

    def self.version_numbers = config.fetch('versions').map { |v| v['number'] }.freeze

    def self.latest = new(config.fetch('latest'))

    # Suitable for showing in a `select` form field. Pinnable versions are
    # ordered newest-first by semantic version — never by manifest order.
    def self.options
      newest_first = version_numbers.sort_by { |number| Gem::Version.new(number) }.reverse
      [{ "Always track latest (currently v#{latest.number})" => 'latest' }] +
        newest_first.map { |number| { "v#{number}" => number } }
    end

    def initialize(number, asset_host: DEFAULT_ASSET_HOST)
      @asset_host = asset_host

      if number.nil? || number == 'latest'
        @number = self.class.config.fetch('latest')
        @pinned = false
      elsif self.class.version_numbers.include?(number)
        @number = number
        @pinned = true
      else
        raise ArgumentError, "unknown framework version: #{number}"
      end
    end

    def pinned? = @pinned

    # Both a pinned and an unpinned ("latest") version resolve to a
    # concrete release here — #number is never the literal "latest" — so a
    # local preview renders the same bundle as the hosted service instead
    # of drifting onto a new release the moment one ships.
    def css_url = "#{@asset_host}/css/#{number}/plugins.css"

    def js_url = "#{@asset_host}/js/#{number}/plugins.js"

    def ==(other) = other.is_a?(self.class) && number == other.number

    def <=>(other)
      return nil unless other.is_a?(self.class)

      Gem::Version.new(number) <=> Gem::Version.new(other.number)
    end

    def as_json(*) = number

    def to_s = number
  end
end
