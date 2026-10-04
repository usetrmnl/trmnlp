# frozen_string_literal: true

require 'json'

module TRMNLP
  module Testing
    # A test's canned answers for the requests a run makes, and the record of those requests. Polling asks it
    # through #call, standing in for OutboundRequest; the transform's requests reach it through MockProxy.
    #
    # Keys are urls: exact, with `*` wildcards, or a Regexp; a key may start with a method ("POST https://...").
    # A value is an answer ({ json:, body:, status:, headers:, delay:, body_delay:, advance_clock:, error: :reset }),
    # in seconds where it is a time; a String body,
    # a lambda that takes the request and returns an answer, or an Array of answers used in order.
    class MockTable
      Response = Struct.new(:status, :headers, :body, :body_delay, :record)
      UNMOCKED_STATUS = 599
      METHOD_PREFIX = /\A(GET|POST|PUT|PATCH|DELETE|HEAD) /

      attr_reader :requests

      def initialize(mocks, on_advance_clock: nil)
        @on_advance_clock = on_advance_clock
        @mocks = (mocks || {}).map { |key, value| { key:, answers: value.is_a?(Array) ? value.dup : [value] } }
        @requests = []
        @lock = Mutex.new
      end

      # [response, failure], as OutboundRequest#call answers.
      def call(verb, url, headers:, body:)
        response = answer(verb, url, headers:, body:, via: :polling)
        response&.record&.[]=(:delivered, true)
        response ? [response, nil] : [nil, 'the connection was reset']
      end

      # Once the run is over: a request whose answer never reached the transform was abandoned by it.
      def finish
        @lock.synchronize do
          @requests.each { |request| request[:aborted] = !request.delete(:delivered) && !request[:reset] }
        end
      end

      # nil when the mock resets the connection. The request is recorded before it is answered, so one the
      # transform abandons during a delay is still there; MockProxy marks it aborted.
      def answer(verb, url, headers: {}, body: nil, via: :polling)
        request = { method: verb.upcase, url:, headers:, body:, via: }
        answer = claim(request)
        entry = record(request.merge(mocked: !answer.nil?, status: nil, aborted: false))
        response = answer.nil? ? unmocked(request) : respond(answer, request)
        response&.record = entry
        entry[:status] = response&.status
        entry[:reset] = true if answer && response.nil?
        response
      end

      private

      def claim(request)
        @lock.synchronize do
          mock = @mocks.find { matches?(it[:key], request) }
          mock && (mock[:answers].size > 1 ? mock[:answers].shift : mock[:answers].first)
        end
      end

      def respond(answer, request)
        answer = answer.call(request) if answer.respond_to?(:call)
        answer = { body: answer } if answer.is_a?(String)
        sleep(answer[:delay]) if answer[:delay]
        @on_advance_clock&.call(answer[:advance_clock]) if answer[:advance_clock]
        answer[:error] == :reset ? nil : build(answer)
      end

      def build(answer)
        json = answer.key?(:json)
        body = json ? JSON.generate(answer[:json]) : answer[:body].to_s
        type = json ? 'application/json' : 'text/plain; charset=utf-8'
        Response.new(answer[:status] || 200, { 'content-type' => type }.merge(answer[:headers] || {}), body,
                     answer[:body_delay])
      end

      def unmocked(request)
        Response.new(UNMOCKED_STATUS, { 'content-type' => 'text/plain' },
                     "trmnlp test: no mock for #{request[:method]} #{request[:url]}")
      end

      def matches?(key, request)
        return key.match?(request[:url]) if key.is_a?(Regexp)

        verb = key[METHOD_PREFIX, 1]
        return false if verb && verb != request[:method]

        pattern = key.sub(METHOD_PREFIX, '')
        target = pattern.include?('?') ? request[:url] : request[:url].split('?', 2).first
        /\A#{Regexp.escape(pattern).gsub('\*', '.*')}\z/.match?(target)
      end

      def record(entry)
        @lock.synchronize { @requests << entry }
        entry
      end
    end
  end
end
