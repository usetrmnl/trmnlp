# frozen_string_literal: true

require_relative '../check'
require_relative '../source'
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
            # Count Liquid output as a CSS value and drop Liquid tags, so every
            # branch's declarations count without evaluating the template.
            css = element['style'].gsub(/\{\{.*?\}\}/m, 'var(--trmnlp-liquid)').gsub(/\{%.*?%\}/m, '')
            Crass.parse_properties(css).count { |token| token[:node] == :property }
          end
          count <= MAX_INLINE_STYLES
        end

        def markup_without_liquid_comments
          source.all_markup.gsub(Source::LIQUID_COMMENT, '')
        end
      end
    end
  end
end
