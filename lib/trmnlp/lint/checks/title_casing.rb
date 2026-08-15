# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class TitleCasing < Check
        MESSAGE = 'Title should begin with a capital letter.'

        private

        def pass?
          name = source.plugin_name
          name.empty? || name[0] == name[0].upcase
        end
      end
    end
  end
end
