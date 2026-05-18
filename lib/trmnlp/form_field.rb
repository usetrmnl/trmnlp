# frozen_string_literal: true

require 'yaml'

module TRMNLP
  # Validates entries in a plugin's settings.yml custom_fields list.
  #
  # The required keys and field-type allowlist are vendored from the hosted
  # service into db/data/form_fields.yml — the same db/data convention
  # FrameworkVersion uses. See that file's header for the refresh policy.
  #
  # Validation is intentionally lenient: it mirrors the hosted service's
  # live form-field validation (presence checks only) and does NOT reject
  # unknown keys — the hosted form views read far more keys than they
  # validate.
  module FormField
    DATA_PATH = File.expand_path('../../db/data/form_fields.yml', __dir__)

    def self.schema = @schema ||= YAML.safe_load_file(DATA_PATH).freeze
    def self.required_keys = schema.fetch('required_keys')
    def self.field_types = schema.fetch('field_types')

    def self.multi_select?(field) = field['field_type'] == 'select' && field['multiple']

    def self.validate(field)
      warnings = []

      required_keys.each do |key|
        warnings << "missing required key: #{key}" unless field.key?(key) || field.key?(key.to_sym)
      end

      type = field['field_type'] || field[:field_type]
      warnings << "unknown field_type: #{type}" if type && !field_types.include?(type)

      warnings
    end

    def self.validate_all(fields)
      Array(fields).flat_map { |field| validate(field) }
    end
  end
end
