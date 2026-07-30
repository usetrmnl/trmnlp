# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # MAX_LENGTH mirrors Plugin::MAX_DESCRIPTION_LENGTH in the hosted
      # service. Refresh it by hand when that constant changes, the same
      # policy db/data/form_fields.yml documents.
      #
      # Only the length is checked — a description is optional, so an
      # absent or empty one passes.
      class DescriptionLength < Check
        MAX_LENGTH = 35
        MESSAGE = "Description should be <= #{MAX_LENGTH} characters long.".freeze

        private

        def pass? = source.plugin_description.length <= MAX_LENGTH
      end
    end
  end
end
