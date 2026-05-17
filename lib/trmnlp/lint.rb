# frozen_string_literal: true

require_relative 'lint/check'
require_relative 'lint/source'
require_relative 'lint/checks/title_casing'
require_relative 'lint/checks/title_length'
require_relative 'lint/checks/layouts_have_content'
require_relative 'lint/checks/no_async_functions'
require_relative 'lint/checks/waits_for_dom_load'
require_relative 'lint/checks/limited_inline_styles'
require_relative 'lint/checks/no_size_classes'
require_relative 'lint/checks/no_opacity'
require_relative 'lint/checks/highcharts_animations_disabled'
require_relative 'lint/checks/highcharts_elements_unique'
require_relative 'lint/checks/image_links_reachable'
require_relative 'lint/checks/custom_fields_used'
require_relative 'lint/checks/form_fields_valid'

module TRMNLP
  # Markup best-practice checks behind `trmnlp lint`.
  module Lint
    # Every check the lint command runs, in report order.
    CHECKS = [
      Checks::TitleCasing,
      Checks::TitleLength,
      Checks::LayoutsHaveContent,
      Checks::NoAsyncFunctions,
      Checks::WaitsForDomLoad,
      Checks::LimitedInlineStyles,
      Checks::NoSizeClasses,
      Checks::NoOpacity,
      Checks::HighchartsAnimationsDisabled,
      Checks::HighchartsElementsUnique,
      Checks::ImageLinksReachable,
      Checks::CustomFieldsUsed,
      Checks::FormFieldsValid
    ].freeze
  end
end
