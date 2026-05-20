# frozen_string_literal: true

require 'sinatra'
require 'sinatra/base'

require_relative 'context'
require_relative 'screen_generator'
require_relative 'screenshot'

module TRMNLP
  class App < Sinatra::Base
    # Sinatra settings
    set :views, File.join(File.dirname(__FILE__), '..', '..', 'web', 'views')
    set :public_folder, File.join(File.dirname(__FILE__), '..', '..', 'web', 'public')

    helpers do
      def format_bytes(bytes)
        bytes < 1024 ? "#{bytes} bytes" : format('%.1f KB', bytes / 1024.0)
      end

      # Colour-codes the payload badge so an author notices when merge
      # variables approach the size the hosted service starts rejecting.
      # KB = 1024, matching format_bytes.
      def payload_size_class(bytes)
        return 'payload-size--over' if bytes >= 100 * 1024
        return 'payload-size--warn' if bytes >= 75 * 1024

        'payload-size--ok'
      end

      # NOTE: render_html.erb's layout yields raw plugin HTML through `<%= yield %>`,
      # so a global `escape_html` setting would corrupt the render. Escape per-value.
      def h(text)
        Rack::Utils.escape_html(text.to_s)
      end
    end

    def initialize(*args)
      super

      @context = settings.context
      @poller = @context.poller
      @renderer = @context.renderer
      @user_data_assembler = @context.user_data_assembler
      @transform_pipeline = @context.transform_pipeline
      @watcher = @context.watcher
      @screenshot = Screenshot.new(pool: settings.browser_pool)

      @poller.poll_data

      @watcher.start if @context.config.project.live_render?

      @live_reload_clients = []
      @watcher.on_change do |view, user_data|
        payload = {
          'type' => 'reload',
          'view' => view,
          'user_data' => user_data
        }
        message = "data: #{payload.to_json}\n\n"
        @live_reload_clients.each { |queue| queue << message }
      end
    end

    post '/webhook' do
      @poller.put_webhook(request.body.read)
      'OK'
    end

    get '/' do
      redirect '/full'
    end

    get '/data' do
      content_type :json
      device = @user_data_assembler.device_from_params(params)
      JSON.pretty_generate(@user_data_assembler.call(device:))
    end

    # Live reload uses rack.hijack so the Puma worker thread is released the
    # instant we have the raw socket — broadcasting then runs on our own
    # thread, never competing with HTTP request workers. Adapted from the
    # Faye::EventSource pattern in faye-websocket (lib/faye/rack_stream.rb)
    # but without the EventMachine dependency: where Faye uses EM.attach to
    # get a reactor callback on socket close, we detect close synchronously
    # via the IOError/EPIPE raised by the next heartbeat write.
    HEARTBEAT_SECONDS = 5

    get '/live_reload' do
      hijack = env['rack.hijack']
      halt 500, 'rack.hijack unavailable' unless hijack
      hijack.call
      io = env['rack.hijack_io']

      queue = Thread::Queue.new
      @live_reload_clients << queue

      Thread.new do
        io.write("HTTP/1.1 200 OK\r\n" \
                 "Content-Type: text/event-stream\r\n" \
                 "Cache-Control: no-cache\r\n" \
                 "Connection: close\r\n\r\n")
        run_live_reload_loop(io, queue)
      rescue IOError, Errno::EPIPE, Errno::ECONNRESET
        # client disconnected mid-write — normal termination
      ensure
        @live_reload_clients.delete(queue)
        io.close
      end

      # -1 status tells the server we've hijacked the response. The body
      # is never iterated; the thread above owns the socket from here.
      [-1, {}, []]
    end

    get '/poll' do
      @poller.poll_data
      redirect back
    end

    Screen.all.each do |screen|
      view = screen.name
      get "/#{view}" do
        @view = view
        device = @user_data_assembler.device_from_params(params)
        user_data = @user_data_assembler.call(device:)
        @user_data = JSON.pretty_generate(user_data)
        # Measured on compact JSON, the way the hosted service sizes merge variables.
        @payload_size = JSON.generate(user_data).bytesize
        @live_reload = @context.config.project.live_render?
        @transform_error = @transform_pipeline.error

        erb :index
      end

      get "/render/#{view}.html" do
        @renderer.render_full_page(view, params)
      end

      get "/render/#{view}.png" do
        @view = view
        html = @renderer.render_full_page(view, params)
        temp_image = render_png(html, params)

        send_file temp_image.path, type: 'image/png', disposition: 'inline'

        temp_image.close
        temp_image.unlink
      end
    end

    private

    # On timeout (queue idle), a colon-prefixed SSE comment line both
    # keeps proxies awake and surfaces a dead client via the next
    # io.write — the route's outer rescue then cleans up.
    def run_live_reload_loop(io, queue)
      loop do
        message = queue.pop(timeout: HEARTBEAT_SECONDS)
        io.write(message || ": heartbeat\n\n")
      end
    end

    # ScreenGenerator is request-scoped — it carries the per-request width,
    # height, and color_depth — so it is built here rather than on the shared
    # Context graph. Screenshots are a serve-only concern and would not belong
    # on a Context shared by every command (build, lint, push, ...).
    def render_png(html, params)
      ScreenGenerator.new(html, screenshot: @screenshot,
                                width: params[:width]&.to_i,
                                height: params[:height]&.to_i,
                                color_depth: params[:color_depth]&.to_i).process
    end
  end
end
