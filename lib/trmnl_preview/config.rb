require 'toml-rb'

module TRMNLPreview
  class Config
    def initialize(root_dir)
      @root_dir = root_dir
      raise("Missing config file #{config_path}") unless File.exist?(config_path)

      reload!
    end

    def reload!
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

    def polling_url_text = polling_urls.join("\r\n") # for {{ trmnl }}

    def polling_verb = @toml['polling_verb'] || 'GET'

    def polling_headers = (@toml['polling_headers'] || {}).transform_values { |v| with_custom_fields(v) }

    def polling_headers_encoded = polling_headers.map { |k, v| "#{k}=#{v}" }.join('&') # for {{ trmnl }}

    def polling_body = with_custom_fields(@toml['polling_body'] || '')

    def user_filters = @toml['custom_filters'] || []

    def live_render? = @toml['live_render'] != false
    
    def dark_mode = @toml['dark_mode'] || 'no'
      
    def watch_paths
      paths = (@toml['watch_paths'] || []) + ['views', 'config.toml', 'static.json']

      paths << static_path if static?

      paths.map { |path| expand_path(path) }.uniq
    end

    def custom_fields
      @toml['custom_fields'] || {}
    end

    def user_data_overrides
      {
        'trmnl' => @toml['trmnl'] || {}
      }
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

    # for interpolating custom_fields into polling_* options
    def with_custom_fields(value)
      custom_fields_with_env = custom_fields.transform_values { |v| with_env(v) }
      Liquid::Template.parse(value).render(custom_fields_with_env)
    end

    # for interpolating ENV vars into custom_fields
    def with_env(value)
      Liquid::Template.parse(value).render({ 'env' => ENV.to_h })
    end
  end
end