# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class TitleBarOutsideLayout < Check
        MESSAGE = "A 'title_bar' is inside a 'layout', so it does not render in its place. " \
                  "Move it out of the 'layout', after it."
        LEARN_MORE = 'https://trmnl.com/framework/docs/title_bar'

        def misplaced_elements
          @misplaced_elements ||= source.html_fragments.flat_map do |path, fragment|
            fragment.css('.layout .title_bar').map { [path, it] }
          end
        end

        private

        def pass? = misplaced_elements.empty?
      end
    end
  end
end
