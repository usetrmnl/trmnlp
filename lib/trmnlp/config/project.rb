require 'trmnl/liquid'
require 'yaml'

module TRMNLP
  class Config
    class Project
      attr_reader :paths

      def initialize(paths)
        @paths = paths
        reload!
      end

      def reload!
        if paths.trmnlp_config.exist?
          @config = YAML.load_file(paths.trmnlp_config)
        else
          @config = {}
        end
      end

      def user_filters = @config['custom_filters'] || []

      def live_render? = !watch_paths.empty?

      def watch_paths
        (@config['watch'] || []).map { |watch_path| paths.expand(watch_path) }.uniq
      end

      def custom_fields = @config.fetch('custom_fields', {}).transform_values(&:to_s)

      def user_data_overrides = @config['variables'] || {}

      # for interpolating custom_fields into polling_* options
      def with_custom_fields(value)
        custom_fields_with_env = custom_fields.transform_values { |v| with_env(v) }
        parse_liquid(value).render(custom_fields_with_env)
      end

      def time_zone = @config['time_zone'] || 'UTC'

      private

      # for interpolating ENV vars into custom_fields
      def with_env(value)
        parse_liquid(value).render({ 'env' => ENV.to_h })
      end

      def parse_liquid(contents)
        Liquid::Template.parse(contents, environment: TRMNL::Liquid.build_environment)
      end
    end
  end
end
