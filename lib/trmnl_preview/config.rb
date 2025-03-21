require 'toml-rb'

module TRMNLPreview
  class Config
    def initialize(paths)
      raise("Missing config file #{paths.config}") unless File.exist?(paths.config)

      @paths = paths
      @toml = TomlRB.load_file(paths.config)

      # Basic validation
      unless ['polling', 'webhook'].include?(strategy)
        raise "Invalid strategy: #{strategy} (must be 'polling' or 'webhook')"
      end
    end

    def strategy = @toml['strategy']

    def url = @toml['url']

    def polling_headers = @toml['polling_headers'] || {}

    def user_filters = @toml['custom_filters'] || []

    def live_render? = @toml['live_render'] != false
      
    def watch_paths
      paths = (@toml['watch_paths'] || []) + ['views']

      paths.map do |path|
        # if path is relative, prepend the root directory
        if File.absolute_path(path) == path
          path
        else
          File.join(@paths.root, path)
        end
      end
    end
  end
end