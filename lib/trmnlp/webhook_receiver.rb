# frozen_string_literal: true

require 'json'

require_relative 'reporter'
require_relative 'webhook_payload'

module TRMNLP
  # Takes a webhook post the way TRMNL does: a serverless plugin transforms the post once, as it
  # arrives, and the result is merged into the stored data. Answers TRMNL's status and JSON body.
  class WebhookReceiver
    MAX_SERVERLESS_INCOMING_BYTES = 1024 * 1024

    def initialize(paths:, transform_pipeline:, user_data_assembler:, reporter: Reporter.new)
      @paths = paths
      @transform_pipeline = transform_pipeline
      @user_data_assembler = user_data_assembler
      @reporter = reporter
    end

    def call(body, params = {})
      payload = WebhookPayload.new(JSON.parse(body), params)
      return reject(payload, payload.rejection) if payload.rejection
      return store(payload, payload.merge_variables) unless transform_pipeline.configured?

      transform_and_store(payload)
    rescue JSON::ParserError => e
      report_warning(e.message)
      [400, { message: e.message }]
    end

    private

    attr_reader :paths, :transform_pipeline, :user_data_assembler, :reporter

    def transform_and_store(payload)
      oversized = serverless_size_rejection(payload)
      return reject(payload, oversized) if oversized

      transformed = user_data_assembler.transform_webhook_post(payload.merge_variables)
      # TRMNL answers before its transform runs, so a failure keeps the stored data and never reaches the poster.
      if transform_pipeline.error
        report_warning("Transform failed: #{transform_pipeline.error}")
      else
        store(payload, transformed)
      end
      [200, { message: nil, merge_variables: payload.merge_variables, processing: 'serverless' }]
    end

    def serverless_size_rejection(payload)
      size = JSON.generate(payload.merge_variables).bytesize
      "Large payload received (#{size} bytes), should be less than 1mb." if size > MAX_SERVERLESS_INCOMING_BYTES
    end

    def store(payload, incoming)
      merged = payload.merged_into(stored_data, incoming)
      payload.size_warning(merged)&.then { report_warning(it) }
      paths.user_data.dirname.mkpath
      paths.user_data.write(JSON.generate(merged))
      [200, { message: nil, merge_variables: merged }]
    end

    def reject(payload, message)
      report_warning(message)
      [422, { message:, merge_variables: stored_data.empty? ? payload.merge_variables : stored_data }]
    end

    def stored_data
      stored = paths.user_data.exist? ? JSON.parse(paths.user_data.read) : {}
      stored.is_a?(Hash) ? stored : {}
    rescue JSON::ParserError
      {}
    end

    def report_warning(message) = reporter.info(reporter.yellow("webhook warning: #{message}"))
  end
end
