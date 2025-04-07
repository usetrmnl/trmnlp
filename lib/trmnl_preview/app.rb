
require 'faye/websocket'
require 'sinatra'
require 'sinatra/base'

require_relative 'context'
require_relative 'screen_generator'

module TRMNLPreview
  class App < Sinatra::Base
    # Sinatra settings
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'web', 'views')
    set :public_folder, File.join(File.dirname(__FILE__), '..', '..', 'web', 'public')
    
    def initialize(*args)
      super

      begin
        @context = Context.new(settings.root_dir)
      rescue StandardError => e
        puts e.message
        exit 1
      end

      @context.poll_data if @context.config.plugin.polling?

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
    
    VIEWS.each do |view|
      get "/#{view}" do
        @view = view
        @user_data = JSON.pretty_generate(@context.user_data)
        @live_reload = @context.config.preview.live_render?

        erb :index
      end

      get "/render/#{view}.html" do
        @view = view
        @screen_classes = @context.screen_classes
        
        erb :render_html do
          @context.render_template(view)
        end
      end

      get "/render/#{view}.bmp" do
        @view = view
        html = @context.render_full_page(view)
        generator = ScreenGenerator.new(html, image: true)
        img_path = generator.process
        send_file img_path, type: 'image/png', disposition: 'inline'
      end
    end
  end
end