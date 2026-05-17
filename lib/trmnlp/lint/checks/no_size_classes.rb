# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class NoSizeClasses < Check
        PATTERN = /\b(view(--|__)(full|half_horizontal|half_vertical|quadrant))\b("|')>/
        MESSAGE = "We already apply the 'full', 'half_horizontal', 'half_vertical', and " \
                  "'quadrant' classes to each view, please remove them."

        private

        def pass? = !source.all_markup.match?(PATTERN)
      end
    end
  end
end
