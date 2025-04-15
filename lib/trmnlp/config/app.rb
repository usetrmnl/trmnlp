require 'yaml'

module TRMNLP
  class Config
    # Stores trmnlp-wide configuration (irrespective of the current plugin)
    class App
      def initialize(paths)
        @paths = paths
        @config = read_config
      end

      def save
        paths.app_config_dir.mkpath
        paths.app_config.write(YAML.dump(@config))
      end

      def logged_in? = api_key && !api_key.empty?
      def logged_out? = !logged_in?

      def api_key = @config['api_key']

      def api_key=(key)
        @config['api_key'] = key
      end

      def base_uri = URI.parse(@config['base_url'] || 'https://usetrmnl.com')

      def api_uri = URI.join(base_uri, '/api')

      def account_uri = URI.join(base_uri, '/account')

      def edit_plugin_settings_uri(id) = URI.join(base_uri, "/plugin_settings/#{id.to_s}/edit")

      def playlists_uri = URI.join(base_uri, '/playlists')

      private

      attr_reader :paths

      def read_config = paths.app_config.exist? ? YAML.safe_load(paths.app_config.read) : {}
    end
  end
end