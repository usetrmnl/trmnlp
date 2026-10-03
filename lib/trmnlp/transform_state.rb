# frozen_string_literal: true

require 'json'

require_relative 'reporter'

module TRMNLP
  # The `trmnl_state` key a transform returns is kept for its next run as trmnl.state instead of rendered.
  class TransformState
    KEY = 'trmnl_state'
    MAX_BYTES = 8 * 1024

    def initialize(paths:, reporter: Reporter.new)
      @paths = paths
      @reporter = reporter
    end

    def read
      paths.transform_state.exist? ? JSON.parse(paths.transform_state.read) : {}
    rescue JSON::ParserError
      {}
    end

    def extract!(output)
      return unless output.is_a?(Hash) && output.key?(KEY)

      state = output.delete(KEY)
      rejection = rejection_reason(state)
      rejection ? reporter.info(reporter.yellow("Ignored #{KEY}: #{rejection}")) : write(state)
    end

    private

    attr_reader :paths, :reporter

    def rejection_reason(state)
      return "expected an object, got #{state.class}" unless state.is_a?(Hash)

      size = JSON.generate(state).bytesize
      "#{size} bytes exceeds the #{MAX_BYTES} byte limit" if size > MAX_BYTES
    end

    def write(state)
      paths.transform_state.dirname.mkpath
      paths.transform_state.write(JSON.generate(state))
    end
  end
end
