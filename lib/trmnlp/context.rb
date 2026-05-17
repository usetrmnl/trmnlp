# frozen_string_literal: true

require_relative 'config'
require_relative 'paths'
require_relative 'poller'
require_relative 'renderer'
require_relative 'reporter'
require_relative 'transform_pipeline'
require_relative 'user_data_assembler'
require_relative 'watcher'

module TRMNLP
  class Context
    attr_reader :config, :paths, :reporter

    def initialize(root_dir, reporter: Reporter.new)
      @paths = Paths.new(root_dir)
      @config = Config.new(paths)
      @reporter = reporter
    end

    # Context is the composition root: it wires and memoizes the runtime
    # object graph. Callers take the collaborator they need and talk to it
    # directly — Context does not forward methods on their behalf.
    def poller = @poller ||= Poller.new(config:, paths:, reporter:)
    def transform_pipeline = @transform_pipeline ||= TransformPipeline.new(config:, paths:, reporter:)
    def user_data_assembler = @user_data_assembler ||= UserDataAssembler.new(config:, paths:, transform_pipeline:)
    def renderer = @renderer ||= Renderer.new(config:, paths:, user_data_assembler:)
    def watcher = @watcher ||= Watcher.new(config:, user_data_assembler:, transform_pipeline:, reporter:)

    def validate!
      raise NotAPlugin, "not a plugin directory (did not find #{paths.trmnlp_config})" unless paths.valid?
    end
  end
end
