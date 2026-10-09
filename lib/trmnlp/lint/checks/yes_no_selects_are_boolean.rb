# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports a settings.yml select whose only options are yes and no — one
      # finding per field. A boolean field shows the same choice as a switch.
      class YesNoSelectsAreBoolean < Check
        YES_NO_VALUE_SETS = [%w[no yes], %w[false true]].freeze
        LEARN_MORE = 'https://help.trmnl.com/en/articles/10513740-custom-plugin-form-builder'

        def issues
          source.custom_field_definitions.select { |field| yes_no_select?(field) }.map do |field|
            { message: "Form field '#{field['keyname']}' is a select with only Yes and No options. " \
                       "Use field_type 'boolean' to show a switch.", learn_more: LEARN_MORE }
          end
        end

        private

        def yes_no_select?(field)
          options = field['options']
          field['field_type'] == 'select' && options.is_a?(Array) && YES_NO_VALUE_SETS.include?(option_values(options))
        end

        # Same value TRMNL submits: a Label: value pair's value, otherwise the option itself.
        def option_values(options)
          options.map { |option| (option.is_a?(Hash) ? option.values.first : option).to_s.downcase }.uniq.sort
        end
      end
    end
  end
end
