# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports markup that draws all of its text with its own <style> block and no framework
      # element. Art and charts that the framework cannot draw are the reviewer's call.
      class FrameworkElementsUsed < Check
        MESSAGE = 'A <style> block draws all the text and no element uses title, value, label or description, ' \
                  'so the text keeps one size on every screen. Use the framework elements with lg: steps.'
        LEARN_MORE = 'https://trmnl.com/framework/docs/3.4/element_sizes'
        STYLE_BLOCK = /<style\b/i
        ELEMENT = /\A(?:title|value|label|description)(?:--|\z)/

        private

        def pass? = source.html_fragments.values.none? { it.at_css('style') } || element_classes?

        def element_classes? = used_classes.any? { it.split(':').last.to_s.match?(ELEMENT) }

        def used_classes = source.html_fragments.values.flat_map { it.css('[class]').flat_map { it['class'].split } }
      end
    end
  end
end
