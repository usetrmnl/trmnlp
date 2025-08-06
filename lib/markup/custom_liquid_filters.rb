require 'action_view'
require 'singleton'
require 'redcarpet'
require 'securerandom'

module Markup
  module CustomLiquidFilters
    class ActionViewHelpers
      include Singleton
      include ActionView::Helpers
    end

    def number_with_delimiter(number, delimiter = ',', separator = ',')
      ActionViewHelpers.instance.number_with_delimiter(number, delimiter: delimiter, separator: separator)
    end

    def number_to_currency(number, unit = '$', delimiter = ',', separator = '.')
      ActionViewHelpers.instance.number_to_currency(number, unit: unit, delimiter: delimiter, separator: separator)
    end

    def l_word(word, locale)
      I18n.t("custom_plugins.#{word}", locale: locale)
    end

    def l_date(date, format, locale = 'en')
      format = format.to_sym unless format.include?('%')
      I18n.l(date.to_datetime, :format => format, locale: locale)
    end

    def pluralize(singular, count)
      ActionViewHelpers.instance.pluralize(count, singular)
    end

    def json(obj)
      JSON.generate(obj)
    end

    # Collections filters
    def group_by(collection, key)
      return {} unless collection.is_a?(Array)
      collection.group_by { |item| item[key] }
    end

    def find_by(collection, key, value, fallback = nil)
      return fallback unless collection.is_a?(Array)
      found = collection.find { |item| item[key] == value }
      found || fallback
    end

    # String, markup, HTML filters
    def markdown_to_html(text)
      renderer = Redcarpet::Render::HTML.new
      markdown = Redcarpet::Markdown.new(renderer)
      markdown.render(text)
    end

    # Date filters
    def days_ago(days)
      (Time.now - (days.to_i * 24 * 60 * 60)).strftime('%Y-%m-%d')
    end

    # Uniqueness filters
    def append_random(string)
      "#{string}#{SecureRandom.alphanumeric(4).downcase}"
    end
  end
end
