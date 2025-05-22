require 'action_view'
require 'singleton'

module Markup
  module CustomLiquidFilters
    class ActionViewHelpers
      include Singleton
      include ActionView::Helpers
    end

    def number_with_delimiter(number, delimiter = ',', separator = ',')
      ActionViewHelpers.instance.number_with_delimiter(number, delimiter:, separator:)
    end

    def number_to_currency(number, unit = '$', delimiter = ',', separator = '.')
      ActionViewHelpers.instance.number_to_currency(number, unit: unit, delimiter:, separator:)
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
  end
end
