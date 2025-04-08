require 'yaml'

module TRMNLP
  class Config
    class Preview
      attr_reader :paths

      def initialize(paths)
        @paths = paths
        reload!
      end

      def reload!
        if paths.preview_config.exist?
          @config = YAML.load_file(paths.preview_config)
        else
          @config = {}
        end
      end

      def user_filters = @config['custom_filters'] || []

      def live_render? = @config['live_render'] != false

      def watch_paths
        watch_paths = (@config['watch_paths'] || []) + ['src', '.trmnlp.yml']
        watch_paths.map { |watch_path| paths.expand(watch_path) }.uniq
      end

      def custom_fields = @config['custom_fields'] || {}

      def user_data_overrides = @config['variables'] || {}

      # for interpolating custom_fields into polling_* options
      def with_custom_fields(value)
        custom_fields_with_env = custom_fields.transform_values { |v| with_env(v) }
        Liquid::Template.parse(value).render(custom_fields_with_env)
      end

      private

      # for interpolating ENV vars into custom_fields
      def with_env(value)
        Liquid::Template.parse(value).render({ 'env' => ENV.to_h })
      end
    end
  end
end