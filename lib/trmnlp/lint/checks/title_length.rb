# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class TitleLength < Check
        MAX_LENGTH = 50
        MESSAGE = "Title should be <= #{MAX_LENGTH} characters long.".freeze

        private

        def pass? = source.plugin_name.length <= MAX_LENGTH
      end
    end
  end
end
