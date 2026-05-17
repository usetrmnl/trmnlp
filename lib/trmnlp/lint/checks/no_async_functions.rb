# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class NoAsyncFunctions < Check
        MESSAGE = 'Async JavaScript functions are not allowed due to browser ' \
                  'timeout settings for generating screenshots.'

        private

        def pass? = !source.all_markup.downcase.include?('async function')
      end
    end
  end
end
