# frozen_string_literal: true

require 'json'

require_relative 'reporter'
require_relative 'transform_client'

module TRMNLP
  # Pipes assembled merge_variables through src/transform.{py,rb,php,js}
  # when a serverless runtime is configured. Mirrors the hosted
  # transform behavior: the transform receives the data (including the
  # trmnl namespace) on stdin and its stdout JSON replaces the data.
  # Failure modes surface via #error (rendered in the preview UI), not
  # raised.
  class TransformPipeline
    attr_reader :error

    def initialize(config:, paths:, reporter: Reporter.new)
      @config = config
      @paths = paths
      @reporter = reporter
    end

    def call(data)
      @error = nil
      transform_path, inferred_language = paths.transform_file
      return data unless transform_path && client

      run(transform_path, inferred_language, data)
    end

    def reset! = @client = nil

    private

    attr_reader :config, :paths, :reporter

    def client = @client ||= TransformClient.from_config(config.project)

    def run(path, inferred_language, data)
      language = config.plugin.serverless_language || inferred_language
      result = client.execute(code: path.read, stdin: JSON.generate(data), language:)
      report_printed_output(result)
      return record_failure(result, data) unless result.success?

      parse_output(result.output, data)
    end

    # The transform's return value travels separately, so stdout holds only what it printed.
    def report_printed_output(result)
      { 'stdout' => result.stdout, 'stderr' => result.stderr }.each do |stream, text|
        reporter.info("transform #{stream}: #{text.strip}") unless text.strip.empty?
      end
    end

    def record_failure(result, fallback)
      @error = result.error || "transform exited #{result.exit_code}: #{result.stderr.strip}"
      reporter.info("transform failed: #{result.error || "exited #{result.exit_code}"}")
      fallback
    end

    def parse_output(output, fallback)
      transformed = JSON.parse(output)
      transformed.is_a?(Hash) ? transformed : wrap_array(transformed)
    rescue JSON::ParserError => e
      @error = "transform produced non-JSON output: #{e.message}"
      reporter.info(@error)
      fallback
    end

    def wrap_array(json) = json.is_a?(Array) ? { data: json } : json
  end
end
