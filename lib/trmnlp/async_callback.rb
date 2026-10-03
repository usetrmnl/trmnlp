# frozen_string_literal: true

require 'json'

require_relative 'reporter'
require_relative 'webhook_payload'

module TRMNLP
  # TRMNL's async_polling handshake: each poll gives the API a callback url with a new version,
  # and only a post to the latest version, within 15 minutes, is stored. Answers TRMNL's status and body.
  class AsyncCallback
    EXPIRY_SECONDS = 15 * 60

    attr_accessor :server_url

    def initialize(config:, paths:, reporter: Reporter.new)
      @config = config
      @paths = paths
      @reporter = reporter
      @version = 0
    end

    def start
      @version += 1
      @expires_at = Time.now + EXPIRY_SECONDS
      "#{server_url}/callback?v=#{@version}"
    end

    def cancel = @expires_at = nil

    def awaiting? = !@expires_at.nil? && !expired?

    def expired? = !@expires_at.nil? && Time.now > @expires_at

    def call(body, version)
      refusal = refusal_for(version)
      return refuse(410, refusal) if refusal

      parsed = JSON.parse(body)
      payload = WebhookPayload.new(parsed.is_a?(Hash) ? parsed.slice('merge_variables') : parsed)
      return refuse(422, payload.rejection) if payload.rejection

      store(payload)
      [200, { status: 'ok' }]
    rescue JSON::ParserError => e
      refuse(400, e.message)
    end

    private

    attr_reader :config, :paths, :reporter

    def refusal_for(version)
      return 'Strategy is not async_polling' unless config.plugin.async_polling?
      return 'No pending async request' unless @expires_at
      return 'Version mismatch' unless version.to_i == @version

      'Async request expired' if expired?
    end

    def store(payload)
      cancel
      payload.size_warning(payload.merge_variables)&.then { report_warning(it) }
      paths.user_data.dirname.mkpath
      paths.user_data.write(JSON.generate(payload.merge_variables))
    end

    def refuse(status, message)
      report_warning(message)
      [status, { message: }]
    end

    def report_warning(message) = reporter.info(reporter.yellow("callback warning: #{message}"))
  end
end
