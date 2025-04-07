require 'xdg'
require 'yaml'

module TRMNLPreview
  class AppConfig
    def initialize
      @config = read_config
    end

    def save
      path.dirname.mkpath
      path.write(YAML.dump(@config))
    end

    def logged_in? = api_key && !api_key.empty?
    def logged_out? = !logged_in?

    def api_key = @config['api_key']

    def api_key=(key)
      @config['api_key'] = key
    end

    def base_uri = URI.parse(@config['base_url'] || 'https://usetrmnl.com')

    def api_uri = URI.join(base_uri, 'api')

    def account_uri = URI.join(base_uri, 'account')

    def path = XDG.new.config_home.join('trmnlp', 'config.yml')

    private

    def read_config = path.exist? ? YAML.safe_load(path.read) : {}
  end
end