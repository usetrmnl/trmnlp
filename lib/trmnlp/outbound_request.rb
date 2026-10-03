# frozen_string_literal: true

require 'cgi'
require 'faraday'
require 'ipaddr'
require 'socket'
require 'timeout'

module TRMNLP
  # One polling request as TRMNL makes it; answers [response, nil] or [nil, failure reason].
  class OutboundRequest
    TIMEOUT_SECONDS = 10
    MAX_REDIRECTS = 5
    REDIRECT_STATUSES = (301..308)
    METHOD_PRESERVING_REDIRECTS = [307, 308].freeze
    PRIVATE_ADDRESS_RANGES = [
      '0.0.0.0/8', '10.0.0.0/8', '100.64.0.0/10', '127.0.0.0/8', '169.254.0.0/16',
      '172.16.0.0/12', '192.0.0.0/24', '192.168.0.0/16', '198.18.0.0/15',
      '::1/128', 'fc00::/7', 'fe80::/10'
    ].map { IPAddr.new(it) }.freeze

    # TRMNL refuses these hosts; a self-hosted server may not, so trmnlp only warns.
    def self.private_address?(url)
      host = URI.parse(url).hostname
      addresses = begin
        [IPAddr.new(host).to_s]
      rescue IPAddr::InvalidAddressError
        Socket.getaddrinfo(host, nil).map { it[3] }.uniq
      end
      addresses.any? { |ip| PRIVATE_ADDRESS_RANGES.any? { it.include?(IPAddr.new(ip)) } }
    rescue URI::Error, SocketError, ArgumentError
      false
    end

    def initialize(on_private_address: ->(_url) {})
      @on_private_address = on_private_address
    end

    def call(verb, url, headers:, body:)
      attempts = 0
      begin
        attempts += 1
        response = Timeout.timeout(TIMEOUT_SECONDS * 2, Faraday::TimeoutError) do
          follow_redirects(verb, encoded(url), headers, body)
        end
        reason = failure_reason(response)
        reason ? [nil, reason] : [response, nil]
      rescue Faraday::TimeoutError, Faraday::ConnectionFailed, Faraday::SSLError => e
        timed_out = e.is_a?(Faraday::TimeoutError) || e.wrapped_exception.is_a?(Net::OpenTimeout)
        retry if timed_out && attempts < 2
        [nil, timed_out ? "no response within #{TIMEOUT_SECONDS}s" : "could not connect (#{e.message})"]
      end
    end

    private

    def follow_redirects(verb, url, headers, body)
      hops = 0
      loop do
        @on_private_address.call(url) if self.class.private_address?(url)
        response = perform(verb, url, headers, body)
        location = response.headers['location']
        return response unless REDIRECT_STATUSES.cover?(response.status) && location && hops < MAX_REDIRECTS

        hops += 1
        next_url = URI.join(url, location).to_s
        unless METHOD_PRESERVING_REDIRECTS.include?(response.status)
          verb = 'GET'
          body = nil
        end
        headers = headers.reject { |name, _| name.to_s.casecmp?('authorization') } if host(url) != host(next_url)
        url = next_url
      end
    end

    # A GET sends the polling body as its query string, as TRMNL does.
    def perform(verb, url, headers, body)
      connection = Faraday.new(url:, headers:, request: { timeout: TIMEOUT_SECONDS, open_timeout: TIMEOUT_SECONDS })
      return connection.post { |request| request.body = body } if verb == 'POST'
      return connection.get if body.to_s.empty?

      connection.get("#{url}#{url.include?('?') ? '&' : '?'}#{body}")
    end

    def failure_reason(response)
      return 'the host replied 429 Too Many Requests' if response.status == 429

      "the host replied #{response.status}" if response.status >= 500
    end

    def host(url) = URI.parse(url).host&.downcase

    # The host stays as typed; only what follows it is percent-encoded.
    def encoded(url)
      scheme_and_host, rest = url.match(%r{\A([a-z][a-z0-9+.-]*://[^/?#]*)(.*)\z}im)&.captures
      scheme_and_host ? scheme_and_host + rest.gsub(/[^\x00-\x7F]/) { CGI.escape(it) } : url
    end
  end
end
