require 'json'
require 'liquid'
require 'open-uri'
require 'sinatra'
require 'sinatra/base'
require 'toml-rb'

require_relative 'liquid_filters'

class TRMNLPreview::App < Sinatra::Base
  # Constants
  VIEWS = %w{full half_horizontal half_vertical quadrant}

  # Sinatra settings
  set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  
  def initialize(*args)
    super

    @config_path = File.join(settings.user_dir, 'config.toml')
    @user_views_dir = File.join(settings.user_dir, 'views')
    @temp_dir = File.join(settings.user_dir, 'tmp')
    @data_json_path = File.join(@temp_dir, 'data.json')

    unless File.exist?(@config_path)
      puts "No config.toml found in #{settings.user_dir}"
      exit 1
    end
  
    unless Dir.exist?(@user_views_dir)
      puts "No views found at #{@user_views_dir}"
      exit 1
    end

    FileUtils.mkdir_p(@temp_dir)

    @config = TomlRB.load_file(@config_path)
    strategy = @config['strategy']
  
    unless ['polling', 'webhook'].include?(strategy)
      puts "Invalid strategy: #{strategy} (must be 'polling' or 'webhook')"
      exit 1
    end
  
    url = @config['url']
    polling_headers = @config['polling_headers'] || {}
  
    if strategy == 'polling'
      if url.nil?
        puts "URL is required for polling strategy"
        exit 1
      end
  
      print "Fetching #{url}... "
      payload = URI.open(url, polling_headers).read
      File.write(@data_json_path, payload)
      puts "got #{payload.size} bytes"
    end
  
    @liquid_environment = Liquid::Environment.build do |env|
      env.register_filter(TRMNLPreview::LiquidFilters)
    end
  end

  post '/webhook' do
    body = request.body.read
    File.write(@data_json_path, body)
    "OK"
  end
  
  get '/' do
    redirect '/full'
  end
  
  VIEWS.each do |view|
    get "/#{view}" do
      @view = view
      erb :index
    end

    get "/render/#{view}" do
      path = File.join(@user_views_dir, "#{view}.liquid")
      unless File.exist?(path)
        halt 404, "Plugin template not found: views/#{view}.liquid"
      end

      user_template = Liquid::Template.parse(File.read(path), environment: @liquid_environment)

      @view = view
      erb :render_view do
        data = JSON.parse(File.read(@data_json_path))
        data = { data: data } if data.is_a?(Array) # per TRMNL docs, bare array is wrapped in 'data' key

        user_template.render(data)
      end
    end
  end
end