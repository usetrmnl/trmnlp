# frozen_string_literal: true

require 'securerandom'
require 'sinatra'
require 'sinatra/base'
require 'yaml'

require_relative 'context'
require_relative 'errors'
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

      # Derived from the live request so it matches at authorize and exchange
      # time; this is the single URI the developer registers with the provider.
      def oauth_callback_uri = "#{request.base_url}/oauth/callback"
    end

    def initialize(*args)
      super

      @context = settings.context
      @poller = @context.poller
      @renderer = @context.renderer
      @user_data_assembler = @context.user_data_assembler
      @transform_pipeline = @context.transform_pipeline
      @watcher = @context.watcher
      @oauth_session = @context.oauth_session
      # Keyed by state. A shared hash (built once) survives Sinatra's
      # per-request dup, like @live_reload_clients below.
      @oauth_state = {}
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

    # API: current project config (custom field values) plus the plugin's
    # field definitions, so the editor can render plugin-declared fields.
    get '/api/config' do
      content_type :json

      # author_bio is informational-only — not a data field a user can set.
      plugin_fields = @context.config.plugin.custom_field_definitions.reject do |field|
        field['field_type'] == 'author_bio'
      end

      {
        custom_fields: @context.config.project.custom_fields,
        plugin_fields: plugin_fields
      }.to_json
    end

    # API: update the project config's custom_fields in .trmnlp.yml
    post '/api/config' do
      content_type :json

      custom_fields = validate_custom_fields!(request.body.read)

      config_path = @context.paths.trmnlp_config
      config = read_project_config(config_path)
      config['custom_fields'] = custom_fields
      config_path.write(YAML.dump(config))

      # Reload config and re-poll so URLs/headers pick up the new values
      @context.config.project.reload!
      @poller.poll_data

      { success: true, custom_fields: @context.config.project.custom_fields }.to_json
    rescue InvalidCustomFields => e
      status 400
      { error: e.message }.to_json
    rescue StandardError => e
      status 500
      { error: e.message }.to_json
    end

    get '/oauth/connect' do
      halt 400, 'OAuth is not configured. Add the oauth_* keys to src/settings.yml.' unless @oauth_session.configured?

      state = SecureRandom.hex(16)
      if @oauth_session.pkce?
        verifier = OAuth::Pkce.verifier
        challenge = OAuth::Pkce.challenge(verifier)
      end
      @oauth_state[state] = verifier
      redirect @oauth_session.authorize_url(redirect_uri: oauth_callback_uri, state:, code_challenge: challenge)
    end

    get '/oauth/callback' do
      halt 400, "OAuth provider returned an error: #{params[:error]}" if params[:error]
      halt 400, 'OAuth state mismatch. Restart at /oauth/connect.' unless @oauth_state.key?(params[:state])

      verifier = @oauth_state.delete(params[:state])
      @oauth_session.complete(code: params[:code], redirect_uri: oauth_callback_uri, code_verifier: verifier)
      @poller.poll_data
      redirect '/'
    rescue StandardError => e
      halt 502, "OAuth token exchange failed: #{e.message}"
    end

    get '/oauth/disconnect' do
      @oauth_session.disconnect
      redirect '/'
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

    # Validates the incoming custom-fields payload, raising InvalidCustomFields
    # (reported to the user as a 400) on bad input. JSON.parse only yields
    # strings, numbers, booleans, nil, arrays, and hashes — all of which
    # Config::Project#custom_fields can stringify — so the meaningful checks
    # are the payload shape and the field names.
    def validate_custom_fields!(body)
      custom_fields = parse_json_object(body).fetch('custom_fields', {})

      unless custom_fields.is_a?(Hash)
        raise InvalidCustomFields, 'custom_fields must be a JSON object of field name/value pairs'
      end

      raise InvalidCustomFields, 'custom field names cannot be blank' if custom_fields.keys.any? { |k| k.strip.empty? }

      custom_fields
    end

    def parse_json_object(body)
      json = JSON.parse(body)
      raise InvalidCustomFields, 'request body must be a JSON object' unless json.is_a?(Hash)

      json
    rescue JSON::ParserError => e
      raise InvalidCustomFields, "request body is not valid JSON: #{e.message}"
    end

    # Mirrors Config::Project#reload! so a round-trip through the editor
    # preserves whatever else lives in .trmnlp.yml.
    def read_project_config(config_path)
      return {} unless config_path.exist?

      YAML.safe_load_file(config_path, permitted_classes: [Date, Time]) || {}
    end

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
