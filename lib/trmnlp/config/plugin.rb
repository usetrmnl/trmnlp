require 'yaml'

module TRMNLP
  class Config
    class Plugin
      def initialize(paths, project_config)
        @paths = paths
        @project_config = project_config
        reload!
      end

      def reload!
        if paths.plugin_config.exist?
          @config = YAML.load_file(paths.plugin_config)
        else
          @config = {}
        end
      end
      
      def strategy = @config['strategy']
      def polling? = strategy == 'polling'
      def webhook? = strategy == 'webhook'
      def static? = strategy == 'static'

      def polling_urls
        # allow project-level config to override
        urls = project_config.user_data_overrides.dig('trmnl', 'plugin_settings', 'polling_url') || @config['polling_url']

        return [] if urls.nil?

        urls.strip.split("\n").map { |url| with_custom_fields(url.strip) }
      end

      def polling_url_text = polling_urls.join("\r\n") # for {{ trmnl }}

      def polling_verb = @config['polling_verb'] || 'GET'

      def polling_headers
        string_to_hash(@config['polling_headers'] || '').transform_values { |v| with_custom_fields(v) }
      end

      def polling_headers_encoded = polling_headers.map { |k, v| "#{k}=#{v}" }.join('&') # for {{ trmnl }}

      def polling_body = with_custom_fields(@config['polling_body'] || '')
      
      def dark_mode = @config['dark_mode'] || 'no'

      def no_screen_padding = @config['no_screen_padding'] || 'no'

      def id = @config['id']

      def static_data
        JSON.parse(@config['static_data'] || '{}')
      rescue JSON::ParserError
        raise Error, 'invalid JSON in static_data'
      end

      private

      attr_reader :paths, :project_config

      def with_custom_fields(value) = project_config.with_custom_fields(value)

      # copied from TRMNL core
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