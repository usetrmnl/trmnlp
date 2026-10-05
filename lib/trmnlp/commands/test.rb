# frozen_string_literal: true

require_relative 'base'

module TRMNLP
  module Commands
    # Runs the plugin's RSpec files (tests/**/*_spec.rb) with `trmnl` and the screen matchers loaded.
    class Test < Base
      Options = Data.define(:dir, :quiet, :update, :report)
      HELPERS = File.expand_path('../testing/rspec.rb', __dir__)
      # The plugin's own setup, loaded before its specs when it exists.
      SPEC_HELPER = 'tests/spec_helper.rb'

      def call(paths = [])
        context.validate!
        require 'rspec/core'

        ENV['TRMNLP_PLUGIN_DIR'] = context.paths.root_dir.to_s
        ENV['TRMNLP_UPDATE_SNAPSHOTS'] = '1' if options.update
        ENV['TRMNLP_REPORT_DIR'] = File.expand_path(options.report) if options.report
        Dir.chdir(context.paths.root_dir) do
          RSpec::Core::Runner.run([*requires, *(paths.empty? ? ['tests'] : paths)]).zero?
        end
      end

      private

      def requires
        files = [HELPERS, (File.expand_path(SPEC_HELPER) if File.exist?(SPEC_HELPER))].compact
        files.flat_map { ['--require', it] }
      end
    end
  end
end
