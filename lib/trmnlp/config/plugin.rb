# frozen_string_literal: true

require 'cgi'
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
      def polling? = strategy == 'polling'
      def webhook? = strategy == 'webhook'
      def static? = strategy == 'static'

      def polling_urls
        # allow project-level config to override
        urls = project_config.user_data_overrides.dig('trmnl', 'plugin_settings',
                                                      'polling_url') || @config['polling_url']

        return [] if urls.nil?

        with_custom_fields(urls).strip.split("\n")
      end

      # for {{ trmnl }}
      def polling_url_text = polling_urls.join("\r\n")

      def polling_verb = @config['polling_verb'] || 'GET'

      def polling_headers
        # NOTE: render Liquid across the full headers string first so {% if %} blocks
        # spanning multiple key=value pairs are preserved. Splitting on
        # '&' or '=' before rendering would shatter tags into multiple values.
        rendered = with_custom_fields(@config['polling_headers'] || '')
        string_to_hash(rendered)
      end

      # for {{ trmnl }}
      def polling_headers_encoded = polling_headers.map { |k, v| "#{k}=#{v}" }.join('&')

      def polling_body = with_custom_fields(@config['polling_body'] || '')

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
      # (default), a pinned version, or nil (treated as latest). See
      # db/data/framework_versions.yml for the supported set.
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

      def with_custom_fields(value) = project_config.with_custom_fields(value)

      def string_to_hash(str, delimiter: '=')
        str.split('&').map do |k_v|
          key, value = k_v.split(delimiter)
          next if value.nil?

          { key => CGI.unescape_uri_component(value) }
        end.compact.reduce({}, :merge)
      end
    end
  end
end
