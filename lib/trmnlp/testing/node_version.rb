# frozen_string_literal: true

require 'open3'

require_relative '../errors'

module TRMNLP
  module Testing
    # Node sends fetch through HTTPS_PROXY only from version 24 (NODE_USE_ENV_PROXY); an older one would
    # skip MockProxy and reach the real network, so a Node transform is refused there rather than run.
    module NodeVersion
      MINIMUM_MAJOR = 24

      module_function

      def check!(interpreter)
        version = checked[interpreter] ||= Open3.capture2(interpreter, '--version').first.strip
        return if version[/\Av?(\d+)/, 1].to_i >= MINIMUM_MAJOR

        raise TestingError, "Mocking a Node transform's requests needs Node #{MINIMUM_MAJOR} or newer, " \
                            "whose fetch honors HTTPS_PROXY; #{interpreter} is #{version}"
      end

      def checked = @checked ||= {}
    end
  end
end
