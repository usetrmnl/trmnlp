require 'active_support/time'
require 'erb'
require 'faraday'
require 'filewatcher'
require 'json'
require 'trmnl/liquid'

require_relative 'config'
require_relative 'paths'

module TRMNLP
  class Context
    attr_reader :config, :paths
    
    def initialize(root_dir)
      @paths = Paths.new(root_dir)
      @config = Config.new(paths)
    end

    def validate!
      raise Error, "not a plugin directory (did not find #{paths.trmnlp_config})" unless paths.valid?
    end

    def start_filewatcher
      @filewatcher_thread ||= Thread.new do
        loop do
          begin
            Filewatcher.new(config.project.watch_paths).watch do |changes|
              config.project.reload!
              config.plugin.reload!
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
      merged_data = base_trmnl_data

      if config.plugin.static?
        merged_data.merge!(config.plugin.static_data)
      elsif paths.user_data.exist?
        merged_data.merge!(JSON.parse(paths.user_data.read))
      end

      # Praise be to ActiveSupport
      merged_data.deep_merge!(config.project.user_data_overrides)
    end

    def poll_data
      return unless config.plugin.polling?

      data = {}

      if config.plugin.polling_urls.empty?
        raise Error, "config must specify polling_url or polling_urls"
      end

      config.plugin.polling_urls.each.with_index do |url, i|
        verb = config.plugin.polling_verb.upcase

        # Convert semicolons to ampersands in query parameters for compatibility
        normalized_url = url.gsub(/;/, '&')

        print "#{verb} #{normalized_url}... "

        conn = Faraday.new(normalized_url:, headers: config.plugin.polling_headers)

        case verb
        when 'GET'
          response = conn.get
        when 'POST'
          response = conn.post do |req|
            req.body = config.plugin.polling_body
          end
        end

        puts "received #{response.body.length} bytes (#{response.status} status)"
        if response.status == 200
          json = wrap_array(JSON.parse(response.body))
        else
          json = {}
          puts response.body
        end
        
        if config.plugin.polling_urls.count == 1
          # For a single polling URL, we just return the JSON directly
          data = json
          break
        else
          # Multiple URLs are namespaced by index
          data["IDX_#{i}"] = json
        end
      end

      write_user_data(data)

      data
    rescue StandardError => e
      puts "error: #{e.message}"
      {}
    end

    def put_webhook(payload)
      data = wrap_array(JSON.parse(payload))
      write_user_data(data)
    rescue
      puts "webhook error: #{e.message}"
    end

    def render_template(view)
      template_path = paths.template(view)
      return "Missing template: #{template_path}" unless template_path.exist?

      shared_template_path = paths.shared_template
      if shared_template_path.exist?
        full_markup = shared_template_path.read + template_path.read
      else
        full_markup = template_path.read
      end

      user_template = Liquid::Template.parse(full_markup, environment: liquid_environment)
      user_template.render(user_data)
    rescue StandardError => e
      e.message
    end

    def render_full_page(view)
      template = paths.render_template.read
      
      ERB.new(template).result(TemplateBinding.new(self, view).get_binding do
        render_template(view)
      end)
    end

    def screen_classes
      classes = 'screen'
      classes << ' screen--no-bleed' if config.plugin.no_screen_padding == 'yes'
      classes << ' dark-mode' if config.plugin.dark_mode == 'yes'
      classes
    end

    private 

    # bindings must match the `GET /render/{view}.html` route in app.rb
    class TemplateBinding
      def initialize(context, view)
        @screen_classes = context.screen_classes
        @view = view
      end

      def get_binding = binding
    end

    def wrap_array(json)
      json.is_a?(Array) ? { data: json } : json
    end

    def base_trmnl_data
      tz = ActiveSupport::TimeZone.find_tzinfo(config.project.time_zone)
      time_zone_iana = tz.name
      time_zone_name = ActiveSupport::TimeZone::MAPPING.invert[time_zone_iana] || time_zone_iana
      utc_offset = tz.utc_offset

      {
        'trmnl' => {
          'user' => {
            'name' => 'name',
            'first_name' => 'first_name',
            'last_name' => 'last_name',
            'locale' => 'en',
            'time_zone' => time_zone_name,
            'time_zone_iana' => time_zone_iana,
            'utc_offset' => utc_offset,
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
            'strategy' => config.plugin.strategy,
            'dark_mode' => config.plugin.dark_mode,
            'polling_headers' => config.plugin.polling_headers_encoded,
            'polling_url' => config.plugin.polling_url_text,
            'custom_fields_values' => config.project.custom_fields
          }
        }
      }
    end

    def liquid_environment
      @liquid_environment ||= TRMNL::Liquid.build_environment do |env|
        config.project.user_filters.each do |module_name, relative_path|
          require paths.root_dir.join(relative_path)
          env.register_filter(Object.const_get(module_name))
        end
      end
    end

    def write_user_data(data)
      paths.create_cache_dir
      paths.user_data.write(JSON.generate(data))
    end
  end
end