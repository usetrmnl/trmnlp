require 'json'
require 'liquid'
require 'open-uri'
require 'sinatra'
require 'sinatra/base'
require 'toml'

require_relative '../trmnl_preview'
require_relative 'liquid_filters'

class TRMNLPreview::App < Sinatra::Base
  set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  
  # Constants
  VIEWS = %w{full half_horizontal half_vertical quadrant}
  CONFIG_PATH = File.join(Dir.pwd, 'config.toml')
  USER_VIEWS_DIR = File.join(Dir.pwd, 'views')
  TEMP_DIR = File.join(Dir.pwd, 'tmp')
  DATA_JSON_PATH = File.join(TEMP_DIR, 'data.json')

  unless File.exist?(CONFIG_PATH)
    puts "No config.toml found in #{Dir.pwd}"
    exit 1
  end

  unless Dir.exist?(USER_VIEWS_DIR)
    puts "No views found at #{USER_VIEWS_DIR}"
    exit 1
  end

  FileUtils.mkdir_p(TEMP_DIR)

  config = TOML.load_file(CONFIG_PATH)
  strategy = config['strategy']

  unless ['polling', 'webhook'].include?(strategy)
    puts "Invalid strategy: #{strategy} (must be 'polling' or 'webhook')"
    exit 1
  end

  url = config['url']
  polling_headers = config['polling_headers'] || {}

  if strategy == 'polling'
    if url.nil?
      puts "URL is required for polling strategy"
      exit 1
    end

    print "Fetching #{url}... "
    payload = URI.open(url, polling_headers).read
    File.write(DATA_JSON_PATH, payload)
    puts "got #{payload.size} bytes"
  end

  environment = Liquid::Environment.build do |env|
    env.register_filter(TRMNLPreview::LiquidFilters)
  end

  get '/' do
    redirect '/full'
  end

  if config['strategy'] == 'webhook'
    post '/webhook' do
      body = request.body.read
      File.write(DATA_JSON_PATH, body)
      "OK"
    end

    puts "Listening for POSTs to /webhook"
  end

  VIEWS.each do |view|
    get "/render/#{view}" do
      path = File.join(USER_VIEWS_DIR, "#{view}.liquid")
      unless File.exist?(path)
        halt 404, "Plugin template not found: views/#{view}.liquid"
      end

      user_template = Liquid::Template.parse(File.read(path), environment: environment)

      @view = view
      erb :render_view do
        data = JSON.parse(File.read(DATA_JSON_PATH))
        data = { data: data } if data.is_a?(Array) # per TRMNL docs, bare array is wrapped in 'data' key

        user_template.render(data)
      end
    end

    get "/#{view}" do
      @view = view
      erb :index
    end
  end
end