# frozen_string_literal: true

require 'erb'
require 'i18n'
require 'active_support'
require 'active_support/number_helper'
require 'active_support/core_ext/string/inflections'

module TRMNL
  module Liquid
    # The ActionView helpers TRMNL::Liquid.load(:rails) gives the filters, without Rails.
    module RailsHelpers
      HTML_ESCAPED_OPTIONS = %i[unit separator delimiter].freeze

      module_function

      def number_to_currency(number, **options)
        number && ActiveSupport::NumberHelper.number_to_currency(number, html_escape_options(options))
      end

      def number_with_delimiter(number, **options)
        number && ActiveSupport::NumberHelper.number_to_delimited(number, html_escape_options(options))
      end

      def pluralize(count, singular, plural: nil, locale: ::I18n.locale)
        word = count == 1 || count.to_s.match?(/^1(\.0+)?$/) ? singular : plural || singular.pluralize(locale)
        "#{count || 0} #{word}"
      end

      def html_escape_options(options)
        options.to_h { |key, value| [key, HTML_ESCAPED_OPTIONS.include?(key) && value ? ERB::Util.html_escape(value) : value] }
      end
    end
  end
end

locale_files = Dir[File.expand_path('../../db/data/locales/*.yml', __dir__)]
I18n.load_path += locale_files
I18n.available_locales = locale_files.map { |path| File.basename(path, '.yml') }
I18n.backend.class.include I18n::Backend::Fallbacks
I18n.fallbacks = I18n::Locale::Fallbacks.new(:en)
