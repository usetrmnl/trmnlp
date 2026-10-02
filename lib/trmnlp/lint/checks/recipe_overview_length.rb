# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Below this many words the hosted service serves the public recipe page
      # with `robots: noindex`, so search engines drop it. The overview is
      # optional (private plugins never show one), so a blank value passes.
      # Words are counted on whitespace; there is no upstream count to match.
      class RecipeOverviewLength < Check
        MIN_WORDS = 100
        MESSAGE = "Recipe overview should be at least #{MIN_WORDS} words long " \
                  'for the recipe page to appear in Google and other search engines.'.freeze

        private

        def pass?
          words = source.recipe_overview.split.size
          words.zero? || words >= MIN_WORDS
        end
      end
    end
  end
end
