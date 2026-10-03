# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports markup that uses a filter only .trmnlp.yml custom_filters defines.
      class NoCustomFilters < Check
        def self.usage_pattern(filter_name) = /\{[{%](?:(?![}%]\}).)*?\|\s*#{Regexp.escape(filter_name)}\b/m

        def issues
          used_filter_names.map do |name|
            { message: "Filter '#{name}' comes from custom_filters in .trmnlp.yml, which TRMNL does not load. " \
                       'TRMNL outputs the value unfiltered; use a built-in filter or the transform instead.' }
          end
        end

        private

        def used_filter_names
          source.local_only_filter_names.select { |name| source.all_markup.match?(self.class.usage_pattern(name)) }
        end
      end
    end
  end
end
