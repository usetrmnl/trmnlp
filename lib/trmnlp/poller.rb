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
    # rubocop:disable-next Metrics/ParameterLists -- keyword collaborators Context wires once
    def initialize(config:, paths:, oauth_session:, trmnl_variables: -> { {} }, reporter: Reporter.new,
                   async_callback: nil, outbound_request: nil)
      @config = config
      @given_outbound_request = outbound_request
      @paths = paths
      @oauth_session = oauth_session
      @trmnl_variables = trmnl_variables
      @reporter = reporter
      @async_callback = async_callback
    end

    def poll_data
      return request_async_data if config.plugin.async_polling?
      return unless config.plugin.polling?

      missing = config.plugin.missing_required_fields
      return report_warning("Plugin is not configured — fill in: #{missing.join(', ')}") if missing.any?

      @fetch_failed = false
      # Like TRMNL: no url is nothing to fetch, and the transform runs on {}.
      data = config.plugin.polling_urls.empty? ? {} : aggregate_responses
      write_user_data(data)
      record_fetch_outcome
      data
    # NOTE: trmnlp is a dev tool — a flaky upstream API should surface a warning
    # and keep the preview server alive, not crash the user's session. We
    # deliberately swallow here and return {} so the renderer keeps rendering.
    rescue StandardError => e
      report_warning(e.message)
      record_fetch_outcome
      {}
    end

    private

    attr_reader :config, :paths, :oauth_session, :trmnl_variables, :reporter, :async_callback

    # Like TRMNL: the API answers 202 and posts the data to callback_url later; the last post renders meanwhile.
    def request_async_data
      unless async_callback&.server_url
        return report_warning('async_polling needs `trmnlp serve` to receive the callback')
      end
      return report_warning('Waiting for the async callback; the last data posted renders') if async_callback.awaiting?
      return if config.plugin.polling_urls.empty?

      report_warning('Async callback not received within 15 minutes') if async_callback.expired?
      response, url = send_async_request(async_callback.start)
      return if response&.status == 202

      async_callback.cancel
      report_warning("Async polling failed: HTTP #{response.status} from #{without_query(url)}") if response
    end

    def send_async_request(callback_url)
      variables = trmnl_variables.call.merge(oauth_session.liquid_variables)
      url = config.plugin.polling_urls(extra_variables: variables.merge('callback_url' => callback_url)).first
      headers = config.plugin.polling_headers(extra_variables: variables)
      [fetch_one(url, headers, config.plugin.polling_body(extra_variables: variables)), url]
    end

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

      size = response.body.length
      reporter.info("#{verb} #{without_query(url)} — received #{size} bytes (#{response.status} status)")
      response
    end

    def outbound_request
      @given_outbound_request || OutboundRequest.new(on_private_address: lambda { |url|
        report_warning("TRMNL refuses #{without_query(url)}: the url resolves to a private address")
      })
    end

    # Like the hosted service: a client error is reported, but its body still reaches the data.
    def parse_response(response, url)
      success = (200..299).cover?(response.status)
      report_warning("HTTP #{response.status} from #{url}") unless success
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
      @fetch_failed = true
      reporter.info(reporter.yellow("warning: #{message}"))
      nil
    end

    # The transform runs later, from the cached data, so whether this poll failed is kept beside it.
    def record_fetch_outcome
      marker = paths.fetch_failed_marker
      return marker.delete if !@fetch_failed && marker.exist?

      marker.dirname.mkpath
      marker.write('') if @fetch_failed
    end

    def write_user_data(data)
      paths.user_data.dirname.mkpath
      paths.user_data.write(JSON.generate(data))
    end
  end
end
