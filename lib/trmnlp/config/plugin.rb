# frozen_string_literal: true

require 'cgi'
require 'json'
require 'yaml'

require_relative '../errors'
require_relative '../framework_version'

module TRMNLP
  class Config
    class Plugin
      def initialize(paths, project_config)
        @paths = paths
        @project_config = project_config
        reload!
      end

      def reload!
        @config = if paths.plugin_config.exist?
                    YAML.safe_load_file(paths.plugin_config, permitted_classes: [Date, Time]) || {}
                  else
                    {}
                  end
      rescue Psych::SyntaxError => e
        raise InvalidConfig, "settings.yml is not valid YAML: #{e.message}"
      end

      def strategy = @config['strategy']
      def refresh_interval = @config['refresh_interval']
      def polling? = strategy == 'polling'
      def webhook? = strategy == 'webhook'
      def static? = strategy == 'static'

      def polling_urls(extra_variables: {})
        # allow project-level config to override
        urls = project_config.user_data_overrides.dig('trmnl', 'plugin_settings',
                                                      'polling_url') || @config['polling_url']

        return [] if urls.nil?

        with_custom_fields(urls, extra_variables:).strip.split("\n")
      end

      # for {{ trmnl }}
      def polling_url_text = polling_urls.join("\r\n")

      def polling_verb = @config['polling_verb'] || 'GET'

      def polling_headers(extra_variables: {})
        # NOTE: render Liquid across the full headers string first so {% if %} blocks
        # spanning multiple key=value pairs are preserved. Splitting on
        # '&' or '=' before rendering would shatter tags into multiple values.
        rendered = with_custom_fields(@config['polling_headers'] || '', extra_variables:)
        string_to_hash(rendered)
      end

      def polling_body(extra_variables: {}) = with_custom_fields(@config['polling_body'] || '', extra_variables:)

      def dark_mode = @config['dark_mode'] || 'no'

      def no_screen_padding = @config['no_screen_padding'] || 'no'

      def id = @config['id']

      def static_data
        JSON.parse(@config['static_data'] || '{}')
      rescue JSON::ParserError
        raise InvalidConfig, 'invalid JSON in static_data'
      end

      # Explicit language for transform.* code. If absent, the language
      # is inferred from the file extension by Paths#transform_file.
      # This one lives on the plugin (settings.yml) because production
      # stores it on the plugin_setting record. The scaffold emits
      # `serverless_language: ''`, so empty strings collapse to nil here
      # to let the `||` in the pipeline fall through to the inferred value.
      def serverless_language
        value = @config['serverless_language']
        value unless value.to_s.empty?
      end

      # The TRMNL design-system version this plugin renders against.
      # Lives on the plugin (settings.yml), like serverless_language,
      # because production stores it on the plugin_setting record — so it
      # round-trips through `trmnlp push` / `pull`. Accepts 'latest'
      # (default), any well-formed version number, or nil (treated as
      # latest) — see FrameworkVersion for why a release the bundled
      # db/data/framework_versions.yml has not heard of is still allowed.
      def framework_version
        FrameworkVersion.new(@config['framework_version'], asset_host: project_config.asset_host)
      rescue ArgumentError => e
        raise InvalidConfig, e.message
      end

      # The custom-field *definitions* declared in settings.yml — the list
      # of field hashes (keyname/name/field_type/...). Distinct from
      # Config::Project#custom_fields, which holds the field *values*.
      def custom_field_definitions = @config['custom_fields'] || []

      # The raw parsed settings.yml hash. Most callers want the semantic
      # readers above; `trmnlp lint` needs the uninterpreted values because
      # it searches the raw {{ }} templates the semantic readers render away.
      def settings = @config

      private

      attr_reader :paths, :project_config

      def with_custom_fields(value, extra_variables: {})
        project_config.with_custom_fields(value, extra_variables:)
      end

      # Mirrors the hosted service's Plugins::Helpers::Transformer#string_to_hash.
      def string_to_hash(str)
        return json_to_hash(str) if str.strip.start_with?('{')

        str.split(/[\n&]/).filter_map do |pair|
          pair = pair.strip
          key, value = pair.split(delimiter_for(pair), 2)
          next if value.nil?

          [key.strip, CGI.unescape_uri_component(value.strip)]
        end.to_h
      end

      # ": " (not ":") so an "https://" URL isn't mistaken for a "Name: Value" header.
      def delimiter_for(pair)
        equals = pair.index('=')
        colon = pair.index(': ')
        return '=' if colon.nil?
        return ': ' if equals.nil?

        colon < equals ? ': ' : '='
      end

      def json_to_hash(str)
        parsed = JSON.parse(str)
        parsed.is_a?(Hash) ? parsed.transform_values(&:to_s) : {}
      rescue JSON::ParserError
        {}
      end
    end
  end
end
