# frozen_string_literal: true

require 'trmnl/liquid'
require 'yaml'
require 'uri'

require_relative '../errors'
require_relative '../framework_version'

module TRMNLP
  class Config
    class Project
      attr_reader :paths

      def initialize(paths, overrides: {})
        @paths = paths
        @overrides = overrides
        reload!
      end

      def reload!
        @config = read_config.merge(@overrides)
      rescue Psych::SyntaxError => e
        raise InvalidConfig, ".trmnlp.yml is not valid YAML: #{e.message}"
      end

      def user_filter_modules
        (@config['custom_filters'] || []).map do |module_name, relative_path|
          require paths.root_dir.join(relative_path)
          Object.const_get(module_name)
        end
      end

      def live_render? = !watch_paths.empty?

      def watch_paths
        ((@config['watch'] || []) + local_asset_override_targets).map { |watch_path| paths.expand(watch_path) }.uniq
      end

      def custom_fields = @config.fetch('custom_fields', {}).transform_values { |v| stringify_field_value(v) }

      # Values with {{ env.X }} filled in, standing in for what a user types into TRMNL's form.
      def custom_fields_with_env = custom_fields.transform_values { |v| with_env(v) }

      def user_data_overrides = @config['variables'] || {}

      # plugin_merge references ("<keyname>_<id>") mapped to the trmnlp project directories that stand in for them.
      def merged_plugins = @config['merged_plugins'] || {}

      # extra_variables lets the poller inject live values (e.g.
      # oauth_access_token) into the same custom-field render.
      def with_custom_fields(value, values:, extra_variables: {})
        parse_liquid(value).render(values.merge(extra_variables))
      end

      def time_zone = @config['time_zone'] || 'UTC'

      def ignored_lint_rules = Array(@config['ignored_lint_rules'])

      # Local override for the framework asset host (offline / mirrored
      # dev). Trmnlp-specific (local dev only) — so it stays in
      # .trmnlp.yml. Consumed by Config::Plugin#framework_version.
      def asset_host = @config['framework_asset_host'] || FrameworkVersion::DEFAULT_ASSET_HOST

      def asset_overrides(extra = {}, allow_inline: false)
        mapping = @config.fetch('asset_overrides', {}) || {}
        raise InvalidConfig, 'asset_overrides must be a mapping' unless mapping.is_a?(Hash)

        normalize_asset_overrides(mapping).merge(normalize_asset_overrides(extra, allow_inline:))
      end

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

      # Read without asset_overrides' checks, so a deleted file does not stop the watcher.
      def local_asset_override_targets
        mapping = @config['asset_overrides']
        mapping.is_a?(Hash) ? mapping.values.grep(String).grep_v(%r{\Ahttps?://}) : []
      end

      def normalize_asset_overrides(mapping, allow_inline: false)
        raise InvalidConfig, 'asset_overrides must be a mapping' unless mapping.is_a?(Hash)

        mapping.to_h do |source, target|
          validate_asset_key!(source)
          [source, normalize_asset_target(source, target, allow_inline:)]
        rescue URI::InvalidURIError
          raise InvalidConfig, "asset_overrides key must be a literal URL: #{source.inspect}"
        end
      end

      def validate_asset_key!(source)
        uri = URI.parse(source.to_s)
        valid = source.is_a?(String) && %w[http https].include?(uri.scheme) && uri.host &&
                !source.match?(/[*{}\[\]\\()|]/)
        raise InvalidConfig, "asset_overrides key must be a literal URL: #{source.inspect}" unless valid
      end

      def normalize_asset_target(source, target, allow_inline:)
        return inline_asset_target(source, target, allow_inline:) if target.is_a?(Hash)
        return url_asset_target(source, target) if target.is_a?(String) && target.match?(%r{\Ahttps?://})

        local_asset_target(source, target)
      end

      def inline_asset_target(source, target, allow_inline:)
        raise InvalidConfig, "asset_overrides #{source}: inline body needs a literal file URL" if source.end_with?('/')
        unless allow_inline && (target.key?(:body) || target.key?('body'))
          raise InvalidConfig, "asset_overrides #{source}: inline body is only allowed in tests"
        end

        target.transform_keys(&:to_sym)
      end

      def url_asset_target(source, target)
        uri = URI.parse(target)
        unless uri.host && (!source.end_with?('/') || target.end_with?('/'))
          raise InvalidConfig, "asset_overrides #{source}: a URL prefix target must end in /"
        end

        target
      end

      def local_asset_target(source, target)
        path = paths.expand(target.to_s)
        raise InvalidConfig, "asset_overrides #{source}: local path does not exist: #{path}" unless path.exist?
        if source.end_with?('/') && !path.directory?
          raise InvalidConfig, "asset_overrides #{source}: a URL prefix needs a local folder"
        end
        if !source.end_with?('/') && path.directory?
          raise InvalidConfig, "asset_overrides #{source}: a folder needs a URL prefix ending in /"
        end

        path.to_s
      end

      def read_config
        return {} unless paths.trmnlp_config.exist?

        YAML.safe_load_file(paths.trmnlp_config, permitted_classes: [Date, Time]) || {}
      end

      # NOTE: arrays (multi-select fields) and hashes are preserved as-is;
      # only their leaf values are stringified to match production
      # behavior.
      def stringify_field_value(value)
        case value
        when Array then value.map { |item| stringify_field_value(item) }
        when Hash then value.transform_values { |item| stringify_field_value(item) }
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
