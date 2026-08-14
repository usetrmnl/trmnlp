# frozen_string_literal: true

require 'date'
require 'faraday'
require 'yaml'

module TRMNLP
  # Represents a TRMNL design-system framework version, so plugins can
  # pin (or float to "latest") the CSS/JS bundle they render against,
  # both in production and locally.
  class FrameworkVersion
    include Comparable

    DEFAULT_ASSET_HOST = 'https://trmnl.com'
    DATA_PATH = File.expand_path('../../db/data/framework_versions.yml', __dir__)
    # DATA_PATH holds a copy of this file, refreshed by `rake framework:sync`.
    MANIFEST_URL = 'https://raw.githubusercontent.com/usetrmnl/trmnl-framework/main/db/data/framework_versions.yml'
    MANIFEST_TIMEOUT = 2

    attr_reader :number

    def self.config = @config ||= (remote_config || YAML.load_file(DATA_PATH)).freeze

    # Answers nil on any failure, so rendering never depends on the network.
    # The shape check rejects error pages, which are also valid YAML.
    def self.remote_config
      response = Faraday.get(MANIFEST_URL) do |request|
        request.options.open_timeout = MANIFEST_TIMEOUT
        request.options.timeout = MANIFEST_TIMEOUT
      end
      return unless response.success?

      # Release dates are quoted today, but the manifest is generated
      # upstream and an unquoted date would otherwise be rejected here.
      manifest = YAML.safe_load(response.body, permitted_classes: [Date])
      manifest if manifest.is_a?(Hash) && manifest.key?('latest') && manifest.key?('versions')
    rescue StandardError
      nil
    end
    private_class_method :remote_config

    def self.version_numbers = config.fetch('versions').map { |v| v['number'] }.freeze

    def self.latest = new(config.fetch('latest'))

    # Suitable for showing in a `select` form field. Pinnable versions are
    # ordered newest-first by semantic version — never by manifest order.
    def self.options
      newest_first = version_numbers.sort_by { |number| Gem::Version.new(number) }.reverse
      [{ "Always track latest (currently v#{latest.number})" => 'latest' }] +
        newest_first.map { |number| { "v#{number}" => number } }
    end

    # A release the manifest has not heard of is still served by the CDN, and
    # the manifest in hand may simply be stale — the bundled copy ages with
    # the gem, and it is what we fall back to whenever the published one is
    # unreachable. So any well-formed number is accepted and only nonsense is
    # rejected; #known? reports whether the manifest lists it.
    def initialize(number, asset_host: DEFAULT_ASSET_HOST)
      @asset_host = asset_host

      if number.nil? || number == 'latest'
        @number = self.class.config.fetch('latest')
        @pinned = false
      else
        @number = validated(number)
        @pinned = true
      end
    end

    def pinned? = @pinned

    def known? = self.class.version_numbers.include?(number)

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

    private

    # Gem::Version is deliberately the only gate: it accepts every number the
    # framework has shipped, and rejects the path traversal or stray markup an
    # unvalidated value would otherwise splice into the asset URLs.
    # Answers a String so an unquoted `framework_version: 3.1` in settings.yml
    # — which YAML hands over as a Float — still compares against the manifest.
    def validated(number)
      Gem::Version.correct?(number) or raise ArgumentError, "invalid framework version: #{number}"

      number.to_s
    end
  end
end
