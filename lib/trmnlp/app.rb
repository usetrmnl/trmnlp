
require 'faye/websocket'
require 'sinatra'
require 'sinatra/base'

require_relative 'api_client'
require_relative 'context'
require_relative 'screen_generator'

module TRMNLP
  class App < Sinatra::Base
    # Sinatra settings
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'web', 'views')
    set :public_folder, File.join(File.dirname(__FILE__), '..', '..', 'web', 'public')
    
    def initialize(*args)
      super

      @context = settings.context

      @context.poll_data

      @context.start_filewatcher if @context.config.project.live_render?

      @live_reload_clients = []
      @context.on_view_change do |view, user_data|
        @live_reload_clients.each do |ws|
          payload = {
            'type' => 'reload',
            'view' => view,
            'user_data' => user_data
          }

          ws.send(payload.to_json)
        end
      end
    end

    post '/webhook' do
      @context.put_webhook(request.body.read)
      "OK"
    end
    
    get '/' do
      redirect '/full'
    end

    get '/data' do
      content_type :json
      JSON.pretty_generate(@context.user_data)
    end

    get '/live_reload' do
      ws = Faye::WebSocket.new(request.env)

      ws.on(:open) do |event|
        @live_reload_clients << ws
      end
  
      ws.on(:close) do |event|
        @live_reload_clients.delete(ws)
      end
  
      ws.rack_response
    end

    get '/poll' do
      @context.poll_data
      redirect back
    end

    # API: List plugins from TRMNL server
    get '/api/plugins' do
      content_type :json
      
      return { error: 'Not logged in' }.to_json unless @context.config.app.logged_in?
      
      begin
        api = APIClient.new(@context.config)
        response = api.get_plugin_settings
        response.to_json
      rescue Error => e
        status 500
        { error: e.message }.to_json
      end
    end

    # API: Get current project config (custom_fields) and plugin field definitions
    get '/api/config' do
      content_type :json
      
      # Get custom field definitions from plugin settings.yml
      plugin_custom_fields = @context.config.plugin.custom_fields_definitions rescue []
      
      {
        custom_fields: @context.config.project.custom_fields,
        plugin_fields: plugin_custom_fields,
        logged_in: @context.config.app.logged_in?
      }.to_json
    end

    # API: Update project config (custom_fields)
    post '/api/config' do
      content_type :json
      
      begin
        body = JSON.parse(request.body.read)
        custom_fields = body['custom_fields'] || {}
        
        # Read current config
        config_path = @context.paths.trmnlp_config
        config = config_path.exist? ? YAML.load_file(config_path) : {}
        
        # Update custom_fields
        config['custom_fields'] = custom_fields
        
        # Write back
        config_path.write(YAML.dump(config))
        
        # Reload config and re-poll data
        @context.config.project.reload!
        @context.poll_data
        
        { success: true, custom_fields: @context.config.project.custom_fields }.to_json
      rescue => e
        status 500
        { error: e.message }.to_json
      end
    end

    # API: Pull/load a plugin from TRMNL server (hot-load)
    post '/api/pull/:id' do
      content_type :json
      
      return { error: 'Not logged in' }.to_json unless @context.config.app.logged_in?
      
      begin
        plugin_id = params[:id]
        
        api = APIClient.new(@context.config)
        tempfile = api.get_plugin_setting_archive(plugin_id)
        size = 0
        
        require 'zip'
        Zip::File.open(tempfile.path) do |zip_file|
          zip_file.each do |entry|
            dest_path = @context.paths.src_dir.join(entry.name)
            dest_path.dirname.mkpath
            zip_file.extract(entry, dest_path) { true } # overwrite existing
          end
        end
        
        size = File.size(tempfile.path)
        tempfile.close
        
        # Clear custom_fields in .trmnlp.yml for fresh start with new plugin
        config_path = @context.paths.trmnlp_config
        config = config_path.exist? ? YAML.load_file(config_path) : {}
        config['custom_fields'] = {}
        config_path.write(YAML.dump(config))
        
        # Reload config and re-poll data
        @context.config.project.reload!
        @context.config.plugin.reload!
        @context.poll_data
        
        { success: true, size: size, message: "Plugin loaded (#{size} bytes)" }.to_json
      rescue => e
        status 500
        { error: e.message }.to_json
      end
    end
    
    VIEWS.each do |view|
      get "/#{view}" do
        @view = view
        @user_data = JSON.pretty_generate(@context.user_data)
        @live_reload = @context.config.project.live_render?

        erb :index
      end

      get "/render/#{view}.html" do
        @context.render_full_page(view, params)
      end

      get "/render/#{view}.size" do
        content_type :json
        
        # Calculate HTML size
        html = @context.render_full_page(view, params)
        html_size = html.bytesize
        
        # Calculate PNG size
        width = params[:width] && params[:width].to_i
        height = params[:height] && params[:height].to_i
        color_depth = params[:color_depth] && params[:color_depth].to_i
        
        generator = ScreenGenerator.new(html, image: true, width: width, height: height, color_depth: color_depth)
        temp_image = generator.process
        png_size = File.size(temp_image.path)
        temp_image.close
        temp_image.unlink
        
        { html_size: html_size, png_size: png_size }.to_json
      end
      
      get "/render/#{view}.png" do
        @view = view
        html = @context.render_full_page(view, params)

        # Parse optional rendering params (sent by the web UI for PNG output)
        width = params[:width] && params[:width].to_i
        height = params[:height] && params[:height].to_i
        color_depth = params[:color_depth] && params[:color_depth].to_i

        generator = ScreenGenerator.new(html, image: true, width: width, height: height, color_depth: color_depth)
        temp_image = generator.process
        
        send_file temp_image.path, type: 'image/png', disposition: 'inline'

        temp_image.close
        temp_image.unlink
      end
    end
  end
end