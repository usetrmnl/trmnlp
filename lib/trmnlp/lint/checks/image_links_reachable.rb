# frozen_string_literal: true

require 'net/http'
require 'openssl'
require 'uri'

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Flags static <img> URLs that answer with a non-success status. A
      # network failure (offline, DNS, timeout) is NOT a plugin defect, so
      # those are skipped rather than reported as one.
      class ImageLinksReachable < Check
        MESSAGE = 'One or more <img> tags has a static "src" URL that does not ' \
                  'respond to HTTP GET requests with a success code.'
        TIMEOUT = 5
        UNREACHABLE = [SocketError, Net::OpenTimeout, Net::ReadTimeout,
                       Errno::ECONNREFUSED, Errno::EHOSTUNREACH, OpenSSL::SSL::SSLError].freeze

        private

        def pass? = static_image_urls.all? { |url| reachable?(url) }

        def static_image_urls
          source.all_markup
                .scan(/<img[^>]+src\s*=\s*["']([^"']+)["']/i).flatten
                .map(&:strip)
                .reject { |src| src.empty? || src.include?('{{') || src.start_with?('data:') }
        end

        def reachable?(url)
          return false unless url.match?(%r{\Ahttps?://})

          response = fetch(URI.parse(url))
          response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
        rescue *UNREACHABLE
          true
        rescue StandardError
          false
        end

        def fetch(uri)
          Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https',
                                              open_timeout: TIMEOUT, read_timeout: TIMEOUT) do |http|
            http.get(uri.request_uri)
          end
        end
      end
    end
  end
end
