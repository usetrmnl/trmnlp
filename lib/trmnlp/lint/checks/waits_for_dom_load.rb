# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class WaitsForDomLoad < Check
        MESSAGE = 'JavaScript should listen for the DOMContentLoaded event, not window.onLoad()'
        LEARN_MORE = 'https://help.trmnl.com/en/articles/9510536-private-plugins#h_db7030f8b8'
        FORBIDDEN = ['window.onload', 'window.addeventlistener("load")',
                     "window.addeventlistener('load')"].freeze

        private

        def pass?
          markup = source.all_markup.downcase
          FORBIDDEN.none? { |token| markup.include?(token) }
        end
      end
    end
  end
end
