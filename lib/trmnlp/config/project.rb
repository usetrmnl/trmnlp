# frozen_string_literal: true

require 'trmnl/liquid'
require 'yaml'

require_relative '../errors'
require_relative '../framework_version'

module TRMNLP
  class Config
    class Project
      attr_reader :paths

      def initialize(paths)
        @paths = paths
        reload!
      end

      def reload!
        @config = if paths.trmnlp_config.exist?
                    YAML.safe_load_file(paths.trmnlp_config, permitted_classes: [Date, Time]) || {}
                  else
                    {}
                  end
      rescue Psych::SyntaxError => e
        raise InvalidConfig, ".trmnlp.yml is not valid YAML: #{e.message}"
      end

      def user_filters = @config['custom_filters'] || []

      def live_render? = !watch_paths.empty?

      def watch_paths
        (@config['watch'] || []).map { |watch_path| paths.expand(watch_path) }.uniq
      end

      def custom_fields = @config.fetch('custom_fields', {}).transform_values { |v| stringify_field_value(v) }

      def user_data_overrides = @config['variables'] || {}

      # for interpolating custom_fields into polling_* options
      def with_custom_fields(value)
        custom_fields_with_env = custom_fields.transform_values { |v| with_env(v) }
        parse_liquid(value).render(custom_fields_with_env)
      end

      def time_zone = @config['time_zone'] || 'UTC'

      # Local override for the framework asset host (offline / mirrored
      # dev). Trmnlp-specific (local dev only) — so it stays in
      # .trmnlp.yml. Consumed by Config::Plugin#framework_version.
      def asset_host = @config['framework_asset_host'] || FrameworkVersion::DEFAULT_ASSET_HOST

      # Toggles serverless transform support. Enabled by default; set to
      # 'disabled' in .trmnlp.yml to turn it off. A transform only runs
      # when a src/transform.* file is also present, so the default is
      # inert until the plugin actually ships one. Transforms run
      # in-process via the bundled python/node/php/ruby interpreters; set
      # serverless_daemon_url to route to a remote transform daemon
      # instead. Lives in .trmnlp.yml because this is purely a
      # local-dev decision.
      def transform_runtime = @config['transform_runtime'] || 'enabled'

      # Opt-in URL of a remote transform daemon. When set, transforms
      # POST here instead of running locally — useful for
      # production-fidelity testing or shared team daemons.
      def serverless_daemon_url = @config['serverless_daemon_url']

      # Bearer token for the remote transform daemon. Mirrors Config::App's
      # ENV-first pattern so the secret stays out of version control —
      # $TRMNL_SERVERLESS_DAEMON_API_KEY takes priority, falls through to
      # the .trmnlp.yml key if no env var is set.
      def serverless_daemon_api_key
        env_key = ENV.fetch('TRMNL_SERVERLESS_DAEMON_API_KEY', nil)
        return env_key if env_key && !env_key.empty?

        @config['serverless_daemon_api_key']
      end

      private

      # NOTE: arrays (multi-select fields) and hashes are preserved as-is;
      # only their leaf values are stringified to match production
      # behavior.
      def stringify_field_value(value)
        case value
        when Array then value.map(&:to_s)
        when Hash then value.transform_values { |v| stringify_field_value(v) }
        else value.to_s
        end
      end

      # for interpolating ENV vars into custom_fields
      def with_env(value)
        return value.map { |v| with_env(v) } if value.is_a?(Array)
        return value.transform_values { |v| with_env(v) } if value.is_a?(Hash)

        parse_liquid(value).render({ 'env' => ENV.to_h })
      end

      def parse_liquid(contents)
        Liquid::Template.parse(contents, environment: TRMNL::Liquid.new)
      end
    end
  end
end
