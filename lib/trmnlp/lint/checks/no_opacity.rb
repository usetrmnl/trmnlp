# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class NoOpacity < Check
        MESSAGE = 'Opacity should not be used, use the "--gray--##" Framework classes instead.'
        LEARN_MORE = 'https://trmnl.com/framework/docs/text_color'
        PATTERN = /opacity:\s*[\d.]+/

        private

        def pass? = !source.all_markup.match?(PATTERN)
      end
    end
  end
end
