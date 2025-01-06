require 'json'
require 'liquid'
require 'open-uri'
require 'sinatra'
require 'sinatra/base'
require 'toml-rb'

require_relative 'context'
require_relative 'liquid_filters'

class TRMNLPreview::App < Sinatra::Base
  # Sinatra settings
  set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  
  def initialize(*args)
    super

    @context = TRMNLPreview::Context.new(settings.user_dir)

    @context.poll_data if @context.strategy == 'polling'
  
    @liquid_environment = Liquid::Environment.build do |env|
      env.register_filter(TRMNLPreview::LiquidFilters)
    end
  end

  post '/webhook' do
    @context.set_data(request.body.read)
    "OK"
  end
  
  get '/' do
    redirect '/full'
  end

  get '/poll' do
    @context.poll_data
    redirect back
  end
  
  TRMNLPreview::VIEWS.each do |view|
    get "/#{view}" do
      @view = view
      erb :index
    end

    get "/render/#{view}" do
      path = @context.view_path(view)
      unless File.exist?(path)
        halt 404, "Plugin template not found: views/#{view}.liquid"
      end

      user_template = Liquid::Template.parse(File.read(path), environment: @liquid_environment)

      @view = view
      erb :render_view do
        user_template.render(@context.user_data)
      end
    end
  end
end