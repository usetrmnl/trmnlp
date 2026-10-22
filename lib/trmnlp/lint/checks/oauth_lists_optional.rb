# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # An xhrSelect that loads its options with {{ oauth_access_token }} has nothing to list until
      # OAuth is connected, and TRMNL will not save the plugin while a required field is empty, the
      # OAuth client ID and secret included. Required, the field blocks the save that would fill it.
      class OauthListsOptional < Check
        LIST_TYPES = %w[xhrSelect xhrSelectSearch].freeze
        TOKEN = /\{\{-?\s*oauth_access_token\b/
        LEARN_MORE = 'https://help.trmnl.com/en/articles/10513740-custom-plugin-form-builder'

        def issues
          blocking_fields.map do |keyname|
            { message: "Form field '#{keyname}' lists its options with the OAuth token but is required. TRMNL will " \
                       'not save the plugin, its OAuth client included, while a required field is empty, and the ' \
                       'list stays empty until OAuth is connected. Add optional: true, and have the markup ask ' \
                       'for a choice while it is empty.',
              learn_more: LEARN_MORE }
          end
        end

        private

        def blocking_fields
          source.custom_field_definitions.filter_map do |field|
            next unless LIST_TYPES.include?(field['field_type']) && !field['optional']
            next unless field['default'].to_s.strip.empty? && field['remote'].to_s.match?(TOKEN)

            field['keyname'].to_s
          end
        end
      end
    end
  end
end
