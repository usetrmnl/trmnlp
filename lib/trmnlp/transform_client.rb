# frozen_string_literal: true

module TRMNLP
  # Strategy host for serverless transform execution. Local plugin
  # development hits the Subprocess backend by default — transforms
  # run in trmnlp's own image alongside Ruby, no daemon required.
  # Setting `serverless_daemon_url` in .trmnlp.yml swaps in the Http
  # backend so plugin authors can target a real remote transform
  # daemon (production parity testing, shared team daemons, etc.).
  class TransformClient
    # Mirrors the remote daemon's ExecResponse. `output` is the canonical
    # JSON result; `stdout` carries user prints.
    Result = Data.define(:stdout, :stderr, :output, :exit_code, :duration_ms, :error) do
      def success? = error.nil? && exit_code.zero?
    end

    attr_reader :backend

    # Returns nil when serverless is disabled in .trmnlp.yml so the
    # pipeline can short-circuit without a per-request check.
    def self.from_config(project_config)
      runtime = project_config.transform_runtime
      return nil if runtime.nil? || runtime.to_s == 'disabled'

      new(backend: backend_for(project_config))
    end

    def self.backend_for(project_config)
      if (url = project_config.serverless_daemon_url)
        TransformBackend::Http.new(url: url, api_key: project_config.serverless_daemon_api_key)
      else
        TransformBackend::Subprocess.new
      end
    end

    def initialize(backend:)
      @backend = backend
    end

    def execute(code:, language:, stdin: '', timeout_seconds: 30)
      backend.execute(code:, language:, stdin:, timeout_seconds:)
    end
  end
end

require_relative 'transform_backend/subprocess'
require_relative 'transform_backend/http'
