# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Matches the hosted service's limit. There is no upstream file to sync
      # from, so update this by hand when that limit changes, the same way
      # db/data/form_fields.yml is kept current.
      class DescriptionLength < Check
        MAX_LENGTH = 35
        MESSAGE = "Description should be <= #{MAX_LENGTH} characters long.".freeze

        private

        def pass? = source.plugin_description.length <= MAX_LENGTH
      end
    end
  end
end
