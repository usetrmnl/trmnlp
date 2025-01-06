
require 'sinatra'
require 'sinatra/base'

require_relative 'context'

class TRMNLPreview::App < Sinatra::Base
  # Sinatra settings
  set :views, File.join(File.dirname(__FILE__), '..', '..', 'views')
  
  def initialize(*args)
    super

    @context = TRMNLPreview::Context.new(settings.user_dir)

    @context.poll_data if @context.strategy == 'polling'
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
      @view = view
      erb :render_view do
        @context.render_user_template(view)
      end
    end
  end
end