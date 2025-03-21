require 'toml-rb'

module TRMNLPreview
  class Config
    def initialize(root_dir)
      @root_dir = root_dir
      raise("Missing config file #{config_path}") unless File.exist?(config_path)

      @toml = TomlRB.load_file(config_path)

      validate!
    end

    def root_dir = @root_dir
    
    def temp_dir = File.join(root_dir, 'tmp')

    def views_dir = File.join(root_dir, 'views')

    def data_path = File.join(temp_dir, 'data.json')
    
    def config_path = File.join(root_dir, 'config.toml')
          
    def strategy = @toml['strategy']

    def polling_urls
      if @toml['url']
        puts "'url' option is deprecated. Replace with: 'polling_urls = [#{@toml['url'].inspect}]'"
        [@toml['url']]
      elsif @toml['polling_urls']
        @toml['polling_urls']
      else
        []
      end
    end

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
          File.join(root_dir, path)
        end
      end
    end

    private

    def validate!
      unless ['polling', 'webhook', 'static'].include?(strategy)
        raise "Invalid strategy: #{strategy} (must be 'polling', 'webhook', or 'static')"
      end
    end
  end
end