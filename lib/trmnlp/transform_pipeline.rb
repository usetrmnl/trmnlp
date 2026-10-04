# frozen_string_literal: true

require 'json'

require_relative 'reporter'
require_relative 'transform_client'
require_relative 'transform_state'

module TRMNLP
  # Pipes assembled merge_variables through src/transform.{py,rb,php,js}
  # when a serverless runtime is configured. Mirrors the hosted
  # transform behavior: the transform receives the data (including the
  # trmnl namespace) on stdin and its stdout JSON replaces the data.
  # Failure modes surface via #error (rendered in the preview UI), not
  # raised.
  class TransformPipeline
    # TRMNL's serverless runtime stops a transform after this long.
    EXECUTION_TIMEOUT_SECONDS = 5

    attr_reader :error

    def initialize(config:, paths:, reporter: Reporter.new)
      @config = config
      @paths = paths
      @reporter = reporter
      @transform_state = TransformState.new(paths:, reporter:)
    end

    def call(data)
      @error = nil
      transform_path, inferred_language = paths.transform_file
      return data unless transform_path && client

      run(transform_path, inferred_language, data)
    end

    def configured? = !paths.transform_file.first.nil? && !client.nil?

    # What the last run stored for the markup, passed to the next run as trmnl.previous_merge_variables.
    def previous_output
      paths.transform_output.exist? ? JSON.parse(paths.transform_output.read) : {}
    rescue JSON::ParserError
      {}
    end

    def reset! = @client = nil

    private

    attr_reader :config, :paths, :reporter, :transform_state

    def client = @client ||= TransformClient.from_config(config.project)

    def run(path, inferred_language, data)
      language = config.plugin.serverless_language || inferred_language
      result = client.execute(code: path.read, stdin: JSON.generate(data), language:,
                              timeout_seconds: EXECUTION_TIMEOUT_SECONDS)
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
      last_good_output(fallback)
    end

    # TRMNL keeps the last good screen when a transform fails.
    def last_good_output(fallback) = paths.transform_output.exist? ? previous_output : fallback

    def parse_output(output, fallback)
      transformed = JSON.parse(output)
      return reject_non_object_output unless transformed.is_a?(Hash)

      transform_state.extract!(transformed, fetch_failed: config.plugin.polling? && paths.fetch_failed_marker.exist?)
      store_output(without_previous_merge_variables(transformed))
    rescue JSON::ParserError => e
      @error = "transform produced non-JSON output: #{e.message}"
      reporter.info(@error)
      last_good_output(fallback)
    end

    # TRMNL renders nothing from an array or a scalar, and refuses one from a webhook post.
    def reject_non_object_output
      @error = 'Transform output must be a JSON object'
      reporter.info(@error)
      {}
    end

    def store_output(output)
      paths.transform_output.dirname.mkpath
      paths.transform_output.write(JSON.generate(output))
      output
    end

    # A transform that echoes its input at any depth (`{ data: input }`) would store its history and double every run.
    def without_previous_merge_variables(value)
      case value
      when Hash then value.except('previous_merge_variables').transform_values { without_previous_merge_variables(it) }
      when Array then value.map { without_previous_merge_variables(it) }
      else value
      end
    end
  end
end
