# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class NoNestedLayouts < Check
        MESSAGE = "A 'layout' is inside another 'layout', which breaks the render. " \
                  "Use one 'layout' per view, with 'columns' or 'flex' inside it."
        LEARN_MORE = 'https://trmnl.com/framework/docs/layout'

        def misplaced_elements
          @misplaced_elements ||= source.html_fragments.flat_map do |path, fragment|
            fragment.css('.layout .layout').map { [path, it] }
          end
        end

        private

        def pass? = misplaced_elements.empty?
      end
    end
  end
end
