# frozen_string_literal: true

require 'faraday'
require 'json'

require_relative '../transform_client'
require_relative 'wrapper'

module TRMNLP
  module TransformBackend
    # Remote-daemon transform execution. Speaks the production daemon's
    # wire format over HTTP so trmnlp can target a real remote transform
    # daemon (or any compatible server) instead of running transforms
    # locally. Selected by TransformClient.from_config when
    # serverless_daemon_url is set in the project's .trmnlp.yml.
    #
    # The daemon expects code that already includes its own harness
    # (reading stdin, dispatching to run/transform/result, writing the
    # canonical JSON result to FD 3). The shared Wrapper module emits
    # the same harness Subprocess uses, parameterized on a FD-3 sink
    # so a transform behaves identically whether previewed against the
    # daemon or run locally.
    class Http
      SUPPORTED_LANGUAGES = %w[python ruby php node].freeze
      DEFAULT_TIMEOUT = 30
      HTTP_TIMEOUT = 60

      def initialize(url:, api_key: nil, http_timeout: HTTP_TIMEOUT)
        @url = url
        @api_key = api_key
        @http_timeout = http_timeout
      end

      def execute(code:, language:, stdin: '', timeout_seconds: DEFAULT_TIMEOUT)
        lang = language.to_s
        return failure("unsupported serverless_language: #{lang}") unless SUPPORTED_LANGUAGES.include?(lang)

        post(code: Wrapper.for(lang, code, sink_for(lang)), stdin:, timeout: timeout_seconds, language: lang)
      end

      private

      def post(code:, stdin:, timeout:, language:)
        response = connection.post('/execute') do |req|
          req.body = JSON.generate(code:, stdin:, timeout:, language:)
        end

        return failure("daemon HTTP #{response.status}: #{response.body}") unless response.status == 200

        parse(response.body)
      rescue Faraday::ConnectionFailed, Faraday::TimeoutError => e
        failure("transform daemon unreachable at #{@url}: #{e.message}")
      rescue JSON::ParserError => e
        failure("daemon returned non-JSON response: #{e.message}")
      end

      def parse(body)
        parsed = JSON.parse(body)
        TransformClient::Result.new(
          stdout: parsed['stdout'] || '',
          stderr: parsed['stderr'] || '',
          output: parsed['output'].to_s,
          exit_code: parsed['exit_code'] || 0,
          duration_ms: parsed['duration_ms'] || 0,
          error: parsed['error']
        )
      end

      # NOTE: the connection is memoized and never explicitly closed. That is
      # safe only because Faraday's default adapter opens a fresh socket per
      # request — swapping in a persistent adapter here would leak sockets.
      def connection
        @connection ||= Faraday.new(url: @url) do |f|
          f.headers['Content-Type'] = 'application/json'
          f.headers['Authorization'] = "Bearer #{@api_key}" if @api_key
          f.options.timeout = @http_timeout
          f.options.open_timeout = 5
        end
      end

      def failure(message)
        TransformClient::Result.new(stdout: '', stderr: '', output: '', exit_code: -1, duration_ms: 0, error: message)
      end

      # Language-specific FD-3 sink snippets — what the daemon's
      # harness reads from to capture canonical JSON output.
      def sink_for(language)
        case language
        when 'python'
          "os.write(3, json.dumps(output).encode('utf-8'))"
        when 'ruby'
          'IO.new(3).write(JSON.generate(output))'
        when 'node'
          <<~JS.chomp
            Promise.resolve(output).then(o => {
              require('fs').writeSync(3, JSON.stringify(o));
            });
          JS
        when 'php'
          "$fd = fopen('php://fd/3', 'w');\n          fwrite($fd, json_encode($output));\n          fclose($fd);"
        end
      end
    end
  end
end
