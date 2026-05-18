# frozen_string_literal: true

require 'filewatcher'

require_relative 'reporter'

module TRMNLP
  class Watcher
    def initialize(config:, user_data_assembler:, transform_pipeline:, reporter: Reporter.new)
      @config = config
      @user_data_assembler = user_data_assembler
      @transform_pipeline = transform_pipeline
      @reporter = reporter
    end

    def start
      @start ||= Thread.new { run }
    end

    def on_change(&block)
      @view_change_callback = block
    end

    private

    attr_reader :config, :user_data_assembler, :transform_pipeline, :reporter

    def run
      loop do
        watch_cycle
      rescue StandardError => e
        reporter.info("error during live render: #{e}")
      end
    end

    def watch_cycle
      Filewatcher.new(config.project.watch_paths).watch do |changes|
        reload_config!
        notify(changes)
      end
    end

    def reload_config!
      config.project.reload!
      config.plugin.reload!
      transform_pipeline.reset! # config may have changed runtime config
    end

    # NOTE: transform.* changes don't trigger a re-poll — the transform
    # runs inside user_data on every render against the cached polled
    # response (or static_data), so editing the transform updates the
    # preview without re-fetching the API.
    def notify(changes)
      data = user_data_assembler.call
      return unless @view_change_callback

      changes.each_key { |path| @view_change_callback.call(File.basename(path, '.liquid'), data) }
    end
  end
end
