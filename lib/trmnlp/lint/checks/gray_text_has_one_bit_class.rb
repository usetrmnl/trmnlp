# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Small gray text dithers into dots on a 1-bit screen, so it needs a 1bit: class
      # (1bit:text--black, or 1bit:text--white on a black panel) on the same element.
      class GrayTextHasOneBitClass < Check
        SMALL = /\A(?:label|text|description)--x?small\z/
        GRAY = /\A(?:text--gray(?:-\d+)?|label--gray)\z/
        LEARN_MORE = 'https://trmnl.com/framework/docs/3.4/text_color'

        def issues
          offending_elements.map { |_, element| self.class.class_list(element) }.uniq.map do |classes|
            { message: "'#{classes}' is small gray text with no 1bit: class, so it breaks up " \
                       'into dots on 1-bit screens. Add 1bit:text--black (1bit:text--white on a black background).',
              learn_more: LEARN_MORE }
          end
        end

        def offending_elements
          @offending_elements ||= source.html_fragments.flat_map do |path, fragment|
            fragment.css('[class]').select { small_gray_without_one_bit?(it['class'].split) }.map { [path, it] }
          end
        end

        def self.class_list(element) = element['class'].split.join(' ')

        private

        def small_gray_without_one_bit?(classes)
          classes.any?(SMALL) && classes.any?(GRAY) && classes.none? { it.start_with?('1bit:') }
        end
      end
    end
  end
end
