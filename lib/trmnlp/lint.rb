# frozen_string_literal: true

require_relative 'lint/check'
require_relative 'lint/source'
require_relative 'lint/checks/title_casing'
require_relative 'lint/checks/title_length'
require_relative 'lint/checks/description_length'
require_relative 'lint/checks/recipe_overview_length'
require_relative 'lint/checks/layouts_have_content'
require_relative 'lint/checks/no_async_functions'
require_relative 'lint/checks/waits_for_dom_load'
require_relative 'lint/checks/limited_inline_styles'
require_relative 'lint/checks/no_size_classes'
require_relative 'lint/checks/arbitrary_values_in_range'
require_relative 'lint/checks/no_opacity'
require_relative 'lint/checks/highcharts_animations_disabled'
require_relative 'lint/checks/highcharts_elements_unique'
require_relative 'lint/checks/image_links_reachable'
require_relative 'lint/checks/custom_fields_used'
require_relative 'lint/checks/form_fields_valid'
require_relative 'lint/checks/no_custom_filters'

require_relative 'lint/diagnostic'

module TRMNLP
  # Markup best-practice checks behind `trmnlp lint`.
  module Lint
    # Every check the lint command runs, in report order.
    CHECKS = [
      Checks::TitleCasing,
      Checks::TitleLength,
      Checks::DescriptionLength,
      Checks::RecipeOverviewLength,
      Checks::LayoutsHaveContent,
      Checks::NoAsyncFunctions,
      Checks::WaitsForDomLoad,
      Checks::LimitedInlineStyles,
      Checks::NoSizeClasses,
      Checks::ArbitraryValuesInRange,
      Checks::NoOpacity,
      Checks::HighchartsAnimationsDisabled,
      Checks::HighchartsElementsUnique,
      Checks::ImageLinksReachable,
      Checks::CustomFieldsUsed,
      Checks::FormFieldsValid,
      Checks::NoCustomFilters
    ].freeze

    # Every finding for a plugin, each a Hash with :rule_id, :message, :severity and :locations.
    def self.issues(config:, paths:)
      source = Source.new(config:, paths:)
      CHECKS.flat_map do |type|
        check = type.new(source)
        check.issues.map { |finding| Diagnostic.new(check, source, finding).to_h }
      end.uniq
    end
  end
end
