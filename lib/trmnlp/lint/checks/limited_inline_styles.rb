# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class LimitedInlineStyles < Check
        MAX_INLINE_STYLES = 6
        PROPERTIES = %w[
          justify-content padding margin background-color
          border-radius text-align object-fit font-size
        ].freeze
        MESSAGE = 'Markup uses too many inline styles, add more native Framework classes.'
        LEARN_MORE = 'https://help.trmnl.com/en/articles/11395668-recipe-best-practices#h_3a3eab0712'

        private

        def pass?
          count = PROPERTIES.sum { |property| source.all_markup.scan(property).size }
          count <= MAX_INLINE_STYLES
        end
      end
    end
  end
end
