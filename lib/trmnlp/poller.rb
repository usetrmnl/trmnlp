# frozen_string_literal: true

require 'active_support/core_ext/hash/conversions'
require 'csv'
require 'json'

require_relative 'outbound_request'
require_relative 'reporter'

module TRMNLP
  class Poller
    BYTE_ORDER_MARK = "\xEF\xBB\xBF".b

    # trmnl_variables answers the trmnl namespace TRMNL renders polling urls, headers and bodies with.
    def initialize(config:, paths:, oauth_session:, trmnl_variables: -> { {} }, reporter: Reporter.new)
      @config = config
      @paths = paths
      @oauth_session = oauth_session
      @trmnl_variables = trmnl_variables
      @reporter = reporter
    end

    def poll_data
      return unless config.plugin.polling?

      missing = config.plugin.missing_required_fields
      return report_warning("Plugin is not configured — fill in: #{missing.join(', ')}") if missing.any?
      raise InvalidConfig, 'config must specify polling_url or polling_urls' if config.plugin.polling_urls.empty?

      data = aggregate_responses
      write_user_data(data)
      data
    # NOTE: trmnlp is a dev tool — a flaky upstream API should surface a warning
    # and keep the preview server alive, not crash the user's session. We
    # deliberately swallow here and return {} so the renderer keeps rendering.
    rescue StandardError => e
      report_warning(e.message)
      {}
    end

    private

    attr_reader :config, :paths, :oauth_session, :trmnl_variables, :reporter

    def aggregate_responses
      fetched = fetch_all
      # Like the hosted service: a token rejected before its expiry gets one refresh and retry.
      fetched = fetch_all if fetched.any? { |_url, response| response&.status == 401 } && oauth_session.force_refresh!
      responses = fetched.map { |url, response| response ? parse_response(response, url) : {} }
      return responses.first if responses.size == 1

      responses.each_with_index.with_object({}) { |(r, i), h| h["IDX_#{i}"] = r }
    end

    def fetch_all
      # Resolve once per attempt (it refreshes as a side effect), then share across
      # every URL, header, and body render.
      variables = trmnl_variables.call.merge(oauth_session.liquid_variables)
      headers = config.plugin.polling_headers(extra_variables: variables)
      body = config.plugin.polling_body(extra_variables: variables)
      config.plugin.polling_urls(extra_variables: variables).map { |url| [url, fetch_one(url, headers, body)] }
    end

    def fetch_one(url, headers, body)
      verb = config.plugin.polling_verb.upcase
      response, failure = outbound_request.call(verb, url, headers:, body:)
      return report_warning("Unable to fetch data from url: #{without_query(url)} — #{failure}") if failure

      reporter.info("#{verb} #{url} — received #{response.body.length} bytes (#{response.status} status)")
      response
    end

    def outbound_request
      OutboundRequest.new(on_private_address: lambda { |url|
        report_warning("TRMNL refuses #{without_query(url)}: the url resolves to a private address")
      })
    end

    # Like the hosted service: a client error is reported, but its body still reaches the data.
    def parse_response(response, url)
      success = (200..299).cover?(response.status)
      reporter.info(reporter.yellow("warning: HTTP #{response.status} from #{url}")) unless success
      parse_body(without_byte_order_mark(response.body.to_s), response.headers['content-type'])
    rescue JSON::ParserError, CSV::MalformedCSVError => e
      report_warning("Malformed #{e.is_a?(CSV::MalformedCSVError) ? 'CSV' : 'JSON'} from url: #{url}")
      {}
    end

    # Unlisted and missing content types are read as JSON, as TRMNL does.
    def parse_body(body, content_type_header)
      case content_type_header&.split(';')&.first&.strip
      when 'text/xml', 'application/xml', %r{^application/.+\+xml} then wrap_array(Hash.from_xml(body))
      when 'text/csv' then wrap_array(CSV.parse(body))
      when 'text/plain', 'text/html', 'text/markdown', 'text/x-markdown' then parse_textual_body(body)
      else wrap_array(JSON.parse(body))
      end
    end

    # Some endpoints serve JSON under a textual content type; anything else passes through under `data`.
    def parse_textual_body(body)
      parsed = JSON.parse(body)
      parsed.is_a?(Hash) || parsed.is_a?(Array) ? wrap_array(parsed) : { 'data' => body }
    rescue JSON::ParserError
      { 'data' => body }
    end

    def without_byte_order_mark(body)
      return body unless body.byteslice(0, BYTE_ORDER_MARK.bytesize)&.b == BYTE_ORDER_MARK

      body.byteslice(BYTE_ORDER_MARK.bytesize..)
    end

    # A polling url often carries its api key in the query string.
    def without_query(url) = url.split('?').first

    def wrap_array(json) = json.is_a?(Array) ? { data: json } : json

    def report_warning(message)
      reporter.info(reporter.yellow("warning: #{message}"))
      nil
    end

    def write_user_data(data)
      paths.user_data.dirname.mkpath
      paths.user_data.write(JSON.generate(data))
    end
  end
end
