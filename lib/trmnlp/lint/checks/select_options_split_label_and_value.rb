# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports a select option written as one quoted string, 'Voyager 1: voyager1'. TRMNL reads
      # a string option as a label and saves it lowercased with spaces as underscores, so the
      # value the markup sees is 'voyager_1:_voyager1'. Unquoted, YAML makes it a label and a value.
      class SelectOptionsSplitLabelAndValue < Check
        LABEL_AND_VALUE = /\A[^:]+:\s+\S/
        LEARN_MORE = 'https://help.trmnl.com/en/articles/10513740-custom-plugin-form-builder'

        def issues
          split_options.map do |field_index, option_index|
            field = source.custom_field_definitions[field_index]
            option = field['options'][option_index]
            { message: "Form field '#{field['keyname']}' has the option '#{option}' as one string, so TRMNL saves " \
                       "'#{option.downcase.tr(' ', '_')}'. Write it as 'Label': value to save the value.",
              learn_more: LEARN_MORE }
          end
        end

        # [field index, option index] of the first such option in each select field.
        def split_options
          source.custom_field_definitions.each_with_index.filter_map do |field, field_index|
            options = field['options']
            next unless field['field_type'] == 'select' && options.is_a?(Array)

            option_index = options.index { |option| option.is_a?(String) && option.match?(LABEL_AND_VALUE) }
            [field_index, option_index] if option_index
          end
        end
      end
    end
  end
end
