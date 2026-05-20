# frozen_string_literal: true

require 'filewatcher'

require_relative 'reporter'

# filewatcher 3.0.1's #watch installs `trap('INT') { exit }` (and HUP/TERM)
# unconditionally, clobbering Puma's clean-shutdown handler — Ctrl-C then
# raises SystemExit instead of triggering Puma's graceful stop, which is
# why the container needs three SIGINTs to die. The gem offers no opt-out;
# its supported shutdown is Filewatcher#stop, which we're not using. We
# replace the trap-installing #watch with the rest of its body so signals
# fall through to whatever handler the host process installed (Puma).
Filewatcher.prepend(Module.new do
  def watch(&on_update)
    @on_update = on_update
    @keep_watching = true
    yield({ '' => '' }) if @immediate
    main_cycle
    @end_snapshot = current_snapshot
    finalize(&on_update)
  end
end)

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
