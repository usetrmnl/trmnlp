# frozen_string_literal: true

require_relative 'base'

module TRMNLP
  module Commands
    # Runs the plugin's RSpec files (tests/**/*_spec.rb) with `trmnl` and the screen matchers loaded.
    class Test < Base
      Options = Data.define(:dir, :quiet, :update)
      HELPERS = File.expand_path('../testing/rspec.rb', __dir__)

      def call(paths = [])
        context.validate!
        require 'rspec/core'

        ENV['TRMNLP_PLUGIN_DIR'] = context.paths.root_dir.to_s
        ENV['TRMNLP_UPDATE_SNAPSHOTS'] = '1' if options.update
        Dir.chdir(context.paths.root_dir) do
          RSpec::Core::Runner.run(['--require', HELPERS, *(paths.empty? ? ['tests'] : paths)]).zero?
        end
      end
    end
  end
end
