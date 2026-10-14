# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports margin, padding, gap and position classes written with a leading
      # minus, such as `-mt--2` or `lg:-top--1`. Tailwind spells negative values
      # this way, but no Framework release, from 1.0.0 to 3.4.2, defines a class
      # that starts with a minus, so the class does nothing and nothing says so:
      # an icon nudged up with `-mt--1` stays where it was.
      class NoNegativeSpacing < Check
        LEARN_MORE = 'https://trmnl.com/framework/docs/spacing'

        PATTERN = /
          (?<![\w:-])
          (?<prefix>(?:[a-z0-9]+:)*)
          -(?<family>[mp][trblxy]?|gap|top|right|bottom|left|inset)
          --(?<value>[\w.]+)
          (?![\w-])
        /x

        def issues
          source.all_markup.scan(PATTERN).uniq.map do |prefix, family, value|
            { message: "'#{prefix}-#{family}--#{value}' has no effect: " \
                       "the Framework has no negative '#{family}--' classes.",
              learn_more: LEARN_MORE }
          end
        end
      end
    end
  end
end
