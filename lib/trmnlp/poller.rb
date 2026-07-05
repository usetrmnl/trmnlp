# frozen_string_literal: true

require 'active_support/core_ext/hash/conversions'
require 'faraday'
require 'json'

require_relative 'reporter'

module TRMNLP
  class Poller
    def initialize(config:, paths:, oauth_session:, reporter: Reporter.new)
      @config = config
      @paths = paths
      @oauth_session = oauth_session
      @reporter = reporter
    end

    def poll_data
      return unless config.plugin.polling?
      raise InvalidConfig, 'config must specify polling_url or polling_urls' if config.plugin.polling_urls.empty?

      data = aggregate_responses
      write_user_data(data)
      data
    # NOTE: trmnlp is a dev tool — a flaky upstream API should surface a warning
    # and keep the preview server alive, not crash the user's session. We
    # deliberately swallow here and return {} so the renderer keeps rendering.
    rescue StandardError => e
      reporter.info(reporter.yellow("warning: #{e.message}"))
      {}
    end

    def put_webhook(payload)
      write_user_data(wrap_array(JSON.parse(payload)))
    # NOTE: Same rationale as #poll_data — a bad webhook payload shouldn't take
    # down the dev server. Report a warning and keep serving.
    rescue StandardError => e
      reporter.info(reporter.yellow("webhook warning: #{e.message}"))
    end

    private

    attr_reader :config, :paths, :oauth_session, :reporter

    def aggregate_responses
      # Resolve once per poll (it refreshes as a side effect), then share across
      # every URL, header, and body render.
      oauth_variables = oauth_session.liquid_variables
      urls = config.plugin.polling_urls(extra_variables: oauth_variables)
      responses = urls.map { |url| fetch_one(url, oauth_variables) }
      return responses.first if responses.size == 1

      responses.each_with_index.with_object({}) { |(r, i), h| h["IDX_#{i}"] = r }
    end

    def fetch_one(url, oauth_variables)
      verb = config.plugin.polling_verb.upcase
      response = perform_request(url, verb, oauth_variables)
      reporter.info("#{verb} #{url} — received #{response.body.length} bytes (#{response.status} status)")
      parse_response(response)
    end

    def perform_request(url, verb, oauth_variables)
      conn = Faraday.new(url:, headers: config.plugin.polling_headers(extra_variables: oauth_variables))
      if verb == 'POST'
        conn.post { |req| req.body = config.plugin.polling_body(extra_variables: oauth_variables) }
      else
        conn.get
      end
    end

    def parse_response(response)
      return parse_failure(response.body) unless response.status == 200

      parse_body(response.body, response.headers['content-type'])
    end

    def parse_failure(body)
      reporter.info(body)
      {}
    end

    def parse_body(body, content_type_header)
      content_type = content_type_header&.split(';')&.first&.strip
      case content_type
      when 'application/json', %r{^application/.+\+json} then wrap_array(JSON.parse(body))
      when 'text/xml', 'application/xml', %r{^application/.+\+xml} then wrap_array(Hash.from_xml(body))
      when 'text/html', 'text/plain' then sniff_json(body) || { 'data' => body }
      else log_unknown_type(content_type_header)
      end
    end

    def log_unknown_type(header)
      reporter.info("unknown content type received: #{header}")
      {}
    end

    def wrap_array(json) = json.is_a?(Array) ? { data: json } : json

    def sniff_json(body)
      trimmed = body.to_s.strip
      return nil unless trimmed.start_with?('{', '[')

      wrap_array(JSON.parse(trimmed))
    rescue JSON::ParserError
      nil
    end

    def write_user_data(data)
      paths.create_cache_dir
      paths.user_data.write(JSON.generate(data))
    end
  end
end
