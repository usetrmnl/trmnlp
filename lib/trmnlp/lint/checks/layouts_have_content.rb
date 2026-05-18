# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class LayoutsHaveContent < Check
        MIN_CONTENT_LENGTH = 10
        MESSAGE = 'Some markup layouts are empty, please provide basic treatment.'

        private

        # A view passes when either its own markup or the shared markup
        # carries real content — mirrors the hosted behaviour.
        def pass?
          source.view_markup.values.all? do |markup|
            [markup.length, source.shared_markup.length].max >= MIN_CONTENT_LENGTH
          end
        end
      end
    end
  end
end
