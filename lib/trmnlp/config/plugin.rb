require 'yaml'

module TRMNLP
  class Config
    class Plugin
      def initialize(paths, trmnlp_config)
        @paths = paths
        @trmnlp_config = trmnlp_config
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
        return [] if @config['polling_url'].nil? || @config['polling_url'].empty?

        urls = @config['polling_url'].split("\n").map(&:strip)

        urls.map { |url| with_custom_fields(url) }
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

      attr_reader :paths, :trmnlp_config

      def with_custom_fields(value) = trmnlp_config.with_custom_fields(value)

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