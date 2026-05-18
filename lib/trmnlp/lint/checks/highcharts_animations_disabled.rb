# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class HighchartsAnimationsDisabled < Check
        MESSAGE = 'Highcharts should have animations disabled.'
        LEARN_MORE = 'https://trmnl.com/framework/chart'

        private

        def pass?
          markup = source.all_markup
          return true unless markup.downcase.include?('highcharts')

          markup.match?(/animation:\s{0,6}false/)
        end
      end
    end
  end
end
