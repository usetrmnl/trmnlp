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

    def config_path = File.join(root_dir, 'config.toml')
    
    def temp_dir = File.join(root_dir, 'tmp')

    def views_dir = File.join(root_dir, 'views')

    def data_path
      static? ? static_path : File.join(temp_dir, 'data.json')
    end
    
    def static_path
      expand_path(@toml['static_path'] || 'static.json')
    end
          
    def strategy = @toml['strategy']
    def polling? = strategy == 'polling'
    def webhook? = strategy == 'webhook'
    def static? = strategy == 'static'

    def polling_urls
      urls = if @toml['url']
        puts "'url' option is deprecated. Replace with: 'polling_urls = [#{@toml['url'].inspect}]'"
        [@toml['url']]
      elsif @toml['polling_urls']
        @toml['polling_urls']
      else
        []
      end

      urls.map { |url| with_custom_fields(url) }
    end

    def polling_verb = @toml['polling_verb'] || 'GET'

    def polling_headers = (@toml['polling_headers'] || {}).transform_values { |v| with_custom_fields(v) }

    def polling_body = with_custom_fields(@toml['polling_body'] || '')

    def user_filters = @toml['custom_filters'] || []

    def live_render? = @toml['live_render'] != false
      
    def watch_paths
      paths = (@toml['watch_paths'] || []) + ['views']

      paths << static_path if static?

      paths.map { |path| expand_path(path) }.uniq
    end

    def custom_fields
      @toml['custom_fields'] || {}
    end

    private

    def validate!
      unless ['polling', 'webhook', 'static'].include?(strategy)
        raise "Invalid strategy: #{strategy} (must be 'polling', 'webhook', or 'static')"
      end
    end

    # Always expand paths relative to the root_dir
    def expand_path(path)
      File.expand_path(path, root_dir)
    end

    def with_custom_fields(value)
      Liquid::Template.parse(value).render(custom_fields)
    end
  end
end