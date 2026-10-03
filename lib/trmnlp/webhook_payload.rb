# frozen_string_literal: true

require 'active_support/core_ext/hash/deep_merge'
require 'json'

module TRMNLP
  # A webhook post as TRMNL takes it: merge_variables inside an object, merged into the
  # stored data under merge_strategy, which the body or the query string may carry.
  class WebhookPayload
    MERGE_STRATEGIES = [nil, 'replace', 'deep_merge', 'stream'].freeze
    STORED_SIZE_LIMIT_BYTES = 5 * 1024

    def initialize(body, params = {})
      @params = params.to_h.merge(body.is_a?(Hash) ? body : {})
    end

    def rejection
      strategy = params['merge_strategy']
      return "Invalid merge_strategy: '#{strategy}'" unless MERGE_STRATEGIES.include?(strategy)

      case merge_variables
      when Hash then nil
      when nil, Array then 'Must be nested inside a merge_variables payload object'
      when String then "Received string: '#{merge_variables}', expecting object"
      else 'Expected an object payload'
      end
    end

    def merge_variables
      return @merge_variables if defined?(@merge_variables)

      value = params['merge_variables']
      @merge_variables = value.is_a?(String) ? (parsed_object(value) || value) : value
    end

    # A serverless webhook merges its transform output in place of the posted merge_variables.
    def merged_into(stored, incoming = merge_variables)
      case merge_strategy
      when 'deep_merge' then stored.deep_merge(incoming)
      when 'stream' then streamed_into(stored, incoming)
      else incoming
      end
    end

    # TRMNL refuses a post past its plan's limit; trmnlp cannot know the plan, so it only warns.
    def size_warning(merged)
      size = JSON.generate(merged).bytesize
      "#{size} bytes stored; TRMNL rejects more than 5 kB (10 kB with TRMNL+)" if size > STORED_SIZE_LIMIT_BYTES
    end

    private

    attr_reader :params

    def merge_strategy = params['deep_merge'].to_s == 'true' ? 'deep_merge' : params['merge_strategy']

    def parsed_object(text)
      parsed = JSON.parse(text)
      parsed if parsed.is_a?(Hash)
    rescue JSON::ParserError
      nil
    end

    def streamed_into(stored, incoming)
      limit = params['stream_limit'].to_i
      incoming.to_h do |key, value|
        next [key, value] unless stored[key].is_a?(Array) && value.is_a?(Array)

        combined = stored[key] + value
        [key, limit.positive? ? combined.last(limit) : combined]
      end
    end
  end
end
