# frozen_string_literal: true

module TRMNLP
  # A select field's options as TRMNL saves them: "New York" as new_york, { Label: value } as its value.
  class SelectFieldChoices
    def initialize(field)
      options = field['options']
      @options = options.is_a?(Array) ? options.compact : []
    end

    def pairs
      @pairs ||= @options.map do |option|
        option.is_a?(Hash) ? [option.keys.first, option.values.first] : [option, option.to_s.downcase.tr(' ', '_')]
      end
    end

    # A label becomes its value; a value, or anything the options do not list, is kept as it is.
    def stored_value(input)
      return input.map { stored_value(it) } if input.is_a?(Array)
      return input if input.to_s.empty? || pairs.any? { |_, value| value.to_s == input.to_s }

      pairs.find { |label, _| label.to_s == input.to_s }&.last&.to_s || input
    end
  end
end
