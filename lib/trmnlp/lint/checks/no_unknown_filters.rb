# frozen_string_literal: true

require 'trmnl/liquid'

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports markup that uses a filter neither Liquid nor trmnl-liquid defines, such
      # as a typo or a filter from another Liquid (Jekyll, LiquidJS). TRMNL does not fail
      # on one: it outputs the value unfiltered. custom_filters are no_custom_filters' to report.
      class NoUnknownFilters < Check
        def issues
          unknown_filter_names.map do |name|
            { message: "Filter '#{name}' is not a Liquid or TRMNL filter. TRMNL outputs the value unfiltered; " \
                       'check the name, or use a built-in filter or the transform instead.' }
          end
        end

        private

        def unknown_filter_names
          used_filter_names - environment.filter_method_names - source.local_only_filter_names
        end

        def used_filter_names = source.markup_files.values.flat_map { filter_names(it) }.uniq

        # Liquid's own parse, so a pipe in a string or a raw block is not taken for a filter.
        def filter_names(markup)
          names = []
          template = ::Liquid::Template.parse(markup, environment:)
          ::Liquid::ParseTreeVisitor.for(template.root)
                                    .add_callback_for(::Liquid::Variable) { names.concat(it.filters.map(&:first)) }
                                    .visit
          names
        rescue ::Liquid::SyntaxError
          [] # A template that does not parse fails to render, which says so.
        end

        def environment = @environment ||= TRMNL::Liquid.new
      end
    end
  end
end
