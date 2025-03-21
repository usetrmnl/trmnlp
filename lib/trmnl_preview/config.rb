require 'toml-rb'

module TRMNLPreview
  class Config
    attr_reader :strategy, :url, :polling_headers, :user_filters

    def initialize(path)
      raise("Missing config file #{path}") unless File.exist?(path)

      toml = TomlRB.load_file(path)
      
      @strategy = toml['strategy']
      @url = toml['url']
      @polling_headers = toml['polling_headers'] || {}
      @live_render = toml['live_render'] != false
      @user_filters = toml['custom_filters'] || []

      unless ['polling', 'webhook'].include?(@strategy)
        raise "Invalid strategy: #{strategy} (must be 'polling' or 'webhook')"
      end
    end

    def live_render? = @live_render
  end
end