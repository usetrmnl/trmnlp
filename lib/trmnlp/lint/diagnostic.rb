# frozen_string_literal: true

module TRMNLP
  module Lint
    # Adds reporting metadata without changing a check's existing #issues API.
    # Rule IDs are the snake_case check names and are part of the report contract.
    class Diagnostic
      SETTINGS_KEYS = {
        'title_casing' => 'name', 'title_length' => 'name',
        'description_length' => 'description', 'recipe_overview_length' => 'recipe_overview'
      }.freeze
      MARKUP_PATTERNS = {
        'no_async_functions' => /async function/i,
        'no_opacity' => Checks::NoOpacity::PATTERN,
        'no_size_classes' => Checks::NoSizeClasses::PATTERN,
        'waits_for_dom_load' => Regexp.new(Regexp.union(Checks::WaitsForDomLoad::FORBIDDEN).source, Regexp::IGNORECASE),
        'limited_inline_styles' => /\sstyle\s*=/i,
        'highcharts_animations_disabled' => /highcharts/i,
        'highcharts_elements_unique' => /highcharts/i
      }.freeze

      def initialize(check, source, finding)
        @check = check
        @source = source
        @finding = finding
      end

      def to_h
        finding.merge(rule_id:, severity: 'error', locations: locations.uniq)
      end

      private

      attr_reader :check, :source, :finding

      def rule_id = Lint.rule_id(check.class)

      def locations
        return source.yaml_location('src/settings.yml', SETTINGS_KEYS[rule_id]) if SETTINGS_KEYS.key?(rule_id)
        return source.locations(MARKUP_PATTERNS[rule_id]) if MARKUP_PATTERNS.key?(rule_id)

        case rule_id
        when 'arbitrary_values_in_range' then class_locations
        when 'layouts_have_content' then empty_view_locations
        when 'form_fields_valid' then form_field_locations
        when 'custom_fields_used' then project_field_locations
        when 'no_custom_filters', 'no_unknown_filters' then filter_locations
        when 'image_links_reachable' then source.locations(Regexp.union(check.unreachable_urls))
        else []
        end
      end

      def class_locations
        css_class = finding[:message][/\A'([^']+)'/, 1]
        css_class ? source.locations(Regexp.new(Regexp.escape(css_class))) : []
      end

      def filter_locations
        source.locations(Checks::NoCustomFilters.usage_pattern(finding[:message][/Filter '([^']+)'/, 1]))
      end

      def empty_view_locations
        return [] if source.shared_markup.length >= Checks::LayoutsHaveContent::MIN_CONTENT_LENGTH

        source.view_markup.filter_map do |view, markup|
          if markup.length < Checks::LayoutsHaveContent::MIN_CONTENT_LENGTH
            { path: "src/#{view}.liquid", line: 1, column: 1, snippet: markup }
          end
        end
      end

      def form_field_locations
        warning = finding[:message].split(' — ', 2).last
        source.custom_field_definitions.each_with_index.flat_map do |field, index|
          if FormField.validate(field).include?(warning)
            source.yaml_location('src/settings.yml', 'custom_fields', index)
          else
            []
          end
        end
      end

      def project_field_locations
        key = finding[:message][/Custom field '([^']+)'/, 1]
        return [] unless key

        # Project custom-field values can contain credentials. Show the key,
        # but never echo its value into terminal output or CI artifacts.
        source.yaml_location('.trmnlp.yml', 'custom_fields', key).map do |location|
          location.merge(snippet: "#{key}: [value omitted]")
        end
      end
    end
  end
end
