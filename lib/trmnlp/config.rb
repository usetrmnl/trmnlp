require_relative 'config/app'
require_relative 'config/plugin'
require_relative 'config/project'

module TRMNLP
  class Config
    attr_reader :app, :project, :plugin

    def initialize(path)
      @app = App.new(path)
      @project = Project.new(path)
      @plugin = Plugin.new(path, @project)
    end
  end
end