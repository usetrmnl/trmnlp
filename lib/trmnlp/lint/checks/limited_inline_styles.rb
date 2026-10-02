# frozen_string_literal: true

require_relative '../check'
require 'crass'
require 'nokogiri'

module TRMNLP
  module Lint
    module Checks
      class LimitedInlineStyles < Check
        MAX_INLINE_STYLES = 6
        MESSAGE = 'Markup uses too many inline styles, add more native Framework classes.'
        LEARN_MORE = 'https://help.trmnl.com/en/articles/11395668-recipe-best-practices#h_3a3eab0712'

        private

        def pass?
          count = Nokogiri::HTML.fragment(markup_without_liquid_comments).css('[style]').sum do |element|
            # Dynamic values do not change how many declarations an attribute
            # contains. Substitute a valid CSS value without evaluating Liquid.
            css = element['style'].gsub(/\{\{.*?\}\}/m, 'var(--trmnlp-liquid)')
            Crass.parse_properties(css).count { |token| token[:node] == :property }
          end
          count <= MAX_INLINE_STYLES
        end

        def markup_without_liquid_comments
          source.all_markup.gsub(/\{%-?\s*comment\s*-?%\}.*?\{%-?\s*endcomment\s*-?%\}/m, '')
        end
      end
    end
  end
end
