# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class HighchartsElementsUnique < Check
        MESSAGE = 'To avoid variable shadowing across charts in multiple layouts, ' \
                  'use the append_random filter for your Highcharts elements.'
        LEARN_MORE = 'https://help.trmnl.com/en/articles/10347358-custom-plugin-filters'

        private

        def pass?
          markup = source.all_markup
          return true unless markup.downcase.include?('highcharts')

          markup.match?(/append_random/)
        end
      end
    end
  end
end
