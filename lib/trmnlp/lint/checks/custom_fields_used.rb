# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports custom fields declared in .trmnlp.yml that never appear in the
      # polling settings or the markup — one finding per unused field.
      class CustomFieldsUsed < Check
        SETTINGS_KEYS = %w[polling_url polling_headers polling_body].freeze

        def issues
          source.custom_field_values.keys.reject { |keyname| used?(keyname) }.map do |keyname|
            { message: "Custom field '#{keyname}' is not used in form fields or markup." }
          end
        end

        private

        def used?(keyname)
          pattern = /#{Regexp.escape(keyname)}/
          searchable_settings.match?(pattern) || source.all_markup.match?(pattern)
        end

        def searchable_settings
          @searchable_settings ||= SETTINGS_KEYS.filter_map { |key| source.settings[key] }.join(' ')
        end
      end
    end
  end
end
