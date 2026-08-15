# frozen_string_literal: true

require_relative '../check'
require_relative '../../form_field'

module TRMNLP
  module Lint
    module Checks
      # Validates settings.yml custom_fields against the FormField schema —
      # the same source serve/build use for their startup warnings.
      class FormFieldsValid < Check
        def issues
          FormField.validate_all(source.custom_field_definitions).map do |warning|
            { message: "settings.yml custom_fields — #{warning}" }
          end
        end
      end
    end
  end
end
