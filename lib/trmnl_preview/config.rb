require_relative 'config/app'
require_relative 'config/plugin'
require_relative 'config/preview'

module TRMNLPreview
  class Config
    attr_reader :app, :preview, :plugin

    def initialize(path)
      @app = App.new(path)
      @preview = Preview.new(path)
      @plugin = Plugin.new(path, @preview)
    end
  end
end