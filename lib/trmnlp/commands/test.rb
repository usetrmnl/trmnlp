# frozen_string_literal: true

require_relative 'base'

module TRMNLP
  module Commands
    # Runs the plugin's RSpec files (tests/**/*_spec.rb) with `trmnl` and the screen matchers loaded.
    class Test < Base
      Options = Data.define(:dir, :quiet, :update, :report, :workers) do
        def initialize(dir:, quiet:, update:, report:, workers: nil) = super
      end
      WORKERS_ENV_KEY = 'TRMNLP_TEST_WORKERS'
      HELPERS = File.expand_path('../testing/rspec.rb', __dir__)

      def call(paths = [])
        context.validate!
        require 'rspec/core'

        ENV['TRMNLP_PLUGIN_DIR'] = context.paths.root_dir.to_s
        ENV['TRMNLP_UPDATE_SNAPSHOTS'] = '1' if options.update
        ENV['TRMNLP_REPORT_DIR'] = File.expand_path(options.report) if options.report
        Dir.chdir(context.paths.root_dir) { run(paths.empty? ? ['tests'] : paths) }
      end

      private

      def run(paths)
        outcome = in_parallel(paths) if workers > 1
        outcome.nil? ? RSpec::Core::Runner.run(['--require', HELPERS, *paths]).zero? : outcome
      end

      def in_parallel(paths)
        require_relative '../testing/parallel'
        unless Testing::Parallel.available?
          reporter.info(reporter.yellow('warning: --workers needs fork, which this platform lacks; using one'))
          return nil
        end

        Testing::Parallel.new(paths:, workers:, helpers: HELPERS, report_dir: ENV.fetch('TRMNLP_REPORT_DIR', nil)).call
      end

      def workers = (options.workers || ENV.fetch(WORKERS_ENV_KEY, 1)).to_i
    end
  end
end
