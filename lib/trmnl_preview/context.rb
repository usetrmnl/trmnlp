require 'erb'
require 'fileutils'
require 'filewatcher'
require 'json'
require 'liquid'
require 'open-uri'

require_relative 'config'
require_relative 'custom_filters'
require_relative 'paths'

module TRMNLPreview
  class Context
    attr_reader :config, :paths
    
    def initialize(root, opts = {})
      @paths = Paths.new(root)
      @config = Config.new(@paths)

      unless Dir.exist?(@paths.views_dir)
        raise "No views found at #{@paths.views_dir}"
      end
      
      FileUtils.mkdir_p(@paths.temp_dir)

      @liquid_environment = Liquid::Environment.build do |env|
        env.register_filter(CustomFilters)

        @config.user_filters.each do |module_name, relative_path|
          require File.join(root, relative_path)
          env.register_filter(Object.const_get(module_name))
        end
      end

      start_filewatcher_thread if @config.live_render?
    end

    def start_filewatcher_thread
      Thread.new do
        loop do
          begin
            Filewatcher.new(@config.watch_paths).watch do |changes|
              views = changes.map { |path, _change| File.basename(path, '.liquid') }
              views.each do |view|
                @view_change_callback.call(view) if @view_change_callback
              end
            end
          rescue => e
            puts "Error during live render: #{e}"
          end
        end
      end
    end

    def on_view_change(&block)
      @view_change_callback = block
    end

    def user_data
      JSON.parse(File.read(@paths.data_json))
    end

    def poll_data
      data = {}

      if @config.polling_urls.empty?
        raise "config must specify polling_url or polling_urls"
      end

      @config.polling_urls.each.with_index do |url, i|
        print "Fetching #{url}... "

        if url.match?(/^https?:\/\//)
          payload = URI.open(url, @config.polling_headers).read
        else
          payload = File.read(File.join(@paths.root, url))
        end

        puts "got #{payload.size} bytes"

        json = wrap_array(JSON.parse(payload))
        
        if @config.polling_urls.count == 1
          # For a single polling URL, we just return the JSON directly
          data = json
          break
        else
          # Multiple URLs are namespaced by index
          data["IDX_#{i}"] = json
        end
      end

      File.write(@paths.data_json, JSON.generate(data))
      data
    rescue StandardError => e
      puts "error: #{e.message}"
      {}
    end

    def put_webhook(payload)
      data = wrap_array(JSON.parse(payload))
      payload = JSON.generate(data)
      File.write(@paths.data_json, payload)
    rescue
      puts "webhook error: #{e.message}"
    end

    def view_path(view)
      File.join(@paths.views_dir, "#{view}.liquid")
    end

    def render_template(view)
        path = view_path(view)
        unless File.exist?(path)
          return "Missing plugin template: views/#{view}.liquid"
        end

        user_template = Liquid::Template.parse(File.read(path), environment: @liquid_environment)
        user_template.render(user_data)
    rescue StandardError => e
      e.message
    end

    def render_full_page(view)
      page_erb_template = File.read(File.join(__dir__, '..', '..', 'web', 'views', 'render_html.erb'))
      
      ERB.new(page_erb_template).result(ERBBinding.new(view).get_binding do
        render_template(view)
      end)
    end

    private 

    class ERBBinding
      def initialize(view) = @view = view
      def get_binding = binding
    end

    def wrap_array(json)
      json.is_a?(Array) ? { data: json } : json
    end
  end
end