require 'erb'
require 'faraday'
require 'fileutils'
require 'filewatcher'
require 'json'
require 'liquid'
require 'open-uri'

require_relative 'config'
require_relative 'custom_filters'

module TRMNLPreview
  class Context
    attr_reader :config
    
    def initialize(root, opts = {})
      @config = Config.new(root)

      unless Dir.exist?(@config.views_dir)
        raise "No views found at #{@config.views_dir}"
      end
      
      FileUtils.mkdir_p(@config.temp_dir)

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
              @config.reload! if changes.keys.any? { |path| File.basename(path) == 'config.toml' }
              new_user_data = user_data

              views = changes.map { |path, _change| File.basename(path, '.liquid') }
              views.each do |view|
                @view_change_callback.call(view, new_user_data) if @view_change_callback
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
      merged_data = trmnl_data

      if File.exist?(@config.data_path)
        merged_data.merge!(JSON.parse(File.read(@config.data_path)))
      end

      # Praise be to ActiveSupport
      merged_data.deep_merge!(@config.user_data_overrides)
    end

    def poll_data
      data = {}

      if @config.polling_urls.empty?
        raise "config must specify polling_url or polling_urls"
      end

      @config.polling_urls.each.with_index do |url, i|
        verb = @config.polling_verb.upcase

        print "#{verb} #{url}... "

        conn = Faraday.new(url:, headers: @config.polling_headers)

        case verb
        when 'GET'
          response = conn.get
        when 'POST'
          response = conn.post do |req|
            req.body = @config.polling_body
          end
        end

        puts "got #{response.body.length} bytes (#{response.status} status)"
        if response.status == 200
          json = wrap_array(JSON.parse(response.body))
        else
          json = {}
          puts response.body
        end
        
        if @config.polling_urls.count == 1
          # For a single polling URL, we just return the JSON directly
          data = json
          break
        else
          # Multiple URLs are namespaced by index
          data["IDX_#{i}"] = json
        end
      end

      File.write(@config.data_path, JSON.generate(data))
      data
    rescue StandardError => e
      puts "error: #{e.message}"
      {}
    end

    def put_webhook(payload)
      data = wrap_array(JSON.parse(payload))
      payload = JSON.generate(data)
      File.write(@config.data_path, payload)
    rescue
      puts "webhook error: #{e.message}"
    end

    def view_path(view)
      File.join(@config.views_dir, "#{view}.liquid")
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

    def trmnl_data
      {
        'trmnl' => {
          'user' => {
            'name' => 'name',
            'first_name' => 'first_name',
            'last_name' => 'last_name',
            'locale' => 'en',
            'time_zone' => 'Eastern Time (US & Canada)',
            'time_zone_iana' => 'America/New_York',
            'utc_offset' => -14400
          },
          'device' => {
            'friendly_id' => 'ABC123',
            'percent_charged' => 85.0,
            'wifi_strength' => 90,
            'height' => 480,
            'width' => 800
          },
          'system' => {
            'timestamp_utc' => Time.now.utc.to_i,
          },
          'plugin_settings' => {
            'instance_name' => 'instance_name',
            'strategy' => config.strategy,
            'dark_mode' => config.dark_mode,
            'polling_headers' => config.polling_headers_encoded,
            'polling_url' => config.polling_url_text,
            'custom_fields_values' => config.custom_fields
          }
        }
      }
    end
  end
end