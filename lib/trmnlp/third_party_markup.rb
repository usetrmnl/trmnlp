# frozen_string_literal: true

require 'json'

require_relative 'errors'
require_relative 'form_body'
require_relative 'outbound_request'

module TRMNLP
  # A third-party plugin's markup as TRMNL fetches it: the user's uuid and the trmnl variables posted to the
  # plugin's plugin_markup_url, answered with each view's markup and the merge variables they render with.
  # Like one TRMNL refresh, one answer per device draws every view until #refresh.
  class ThirdPartyMarkup
    STAND_IN_USER_UUID = '00000000-0000-4000-8000-000000000000'
    MARKUP_KEYS = { 'full' => 'markup', 'half_horizontal' => 'markup_half_horizontal',
                    'half_vertical' => 'markup_half_vertical', 'quadrant' => 'markup_quadrant',
                    'shared' => 'shared' }.freeze

    def initialize(settings:, trmnl_variables:, outbound_request: OutboundRequest.new)
      @settings = settings
      @trmnl_variables = trmnl_variables
      @outbound_request = outbound_request
      @answers = {}
    end

    def call(device:) = @answers[device] ||= markups(fetch(device))

    def refresh = @answers.clear

    # The data trmnlp serve shows: a page load is a new refresh, so the plugin is asked again.
    def preview_merge_variables(device:)
      refresh
      call(device:)['merge_variables']
    rescue RenderError => e
      { 'error' => e.message }
    end

    private

    attr_reader :settings, :trmnl_variables, :outbound_request

    def fetch(device)
      user_uuid = settings['user_uuid'] || STAND_IN_USER_UUID
      body = FormBody.encode({ 'user_uuid' => user_uuid }.merge(trmnl_variables.call(device)))
      response, failure = outbound_request.call('POST', url, headers:, body:)
      unavailable!(failure) if failure

      parsed(response)
    end

    def url
      url = settings['plugin_markup_url'].to_s.strip
      return url unless url.empty?

      unavailable!('plugin_markup_url in .trmnlp.yml is empty, so an environment variable it reads is probably not set')
    end

    def headers
      token = settings['access_token'].to_s
      authorization = token.empty? ? {} : { 'Authorization' => "Bearer #{token}" }
      { 'Content-Type' => 'application/x-www-form-urlencoded' }.merge(authorization)
    end

    def parsed(response)
      body = response.body.to_s.delete_prefix("\uFEFF")
      unavailable!("the host replied #{response.status}: #{body[0, 200]}") unless (200..299).cover?(response.status)
      unavailable!("the host replied #{response.status} with an empty body") if body.strip.empty?

      answer = JSON.parse(body)
      answer.is_a?(Hash) ? answer : raise(JSON::ParserError)
    rescue JSON::ParserError
      unavailable!("the host replied #{response.status} with no JSON object: #{body[0, 200]}")
    end

    def unavailable!(reason) = raise(RenderError, "Plugin markup unavailable: #{reason}")

    def markups(answer)
      merge_variables = answer['merge_variables'] || {}
      unusable!('merge_variables must be a JSON object', merge_variables) unless merge_variables.is_a?(Hash)

      MARKUP_KEYS.to_h do |name, key|
        markup = answer[key]
        unusable!("#{key} must be a string", markup) unless markup.nil? || markup.is_a?(String)
        [name, markup]
      end.merge('merge_variables' => merge_variables)
    end

    def unusable!(problem, value)
      raise(RenderError, "Plugin markup unusable: #{problem}, not #{JSON.generate(value)}")
    end
  end
end
