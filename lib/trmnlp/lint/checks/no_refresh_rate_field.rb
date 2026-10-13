# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports a custom field that sets how often the content changes. The refresh rate and the
      # playlist already decide that, so the field repeats them. A field must both be named for
      # it (rotation, refresh, new …) and offer intervals, so data such as "collected every 2 weeks" passes.
      class NoRefreshRateField < Check
        NAME = /rotat|refresh|frequen|interval|how often|\bnew\b|\bnext\b/i
        INTERVAL_OPTION = /\A(?:daily|hourly|(?:once|twice|\d+\stimes)\s(?:a|per)\s(?:day|hour)|
                           every\s(?:\d+\s)?(?:minute|hour|day)s?|\d+\s*(?:minutes?|mins?|hours?|hrs?)\b)/ix
        TIME_UNIT = /\b(?:minutes?|hours?)\b/i
        LEARN_MORE = 'https://help.trmnl.com/en/articles/11395668-recipe-best-practices'

        def issues
          offending_fields.map do |field|
            { message: "Form field '#{field['keyname']}' sets how often the content changes. Remove it and let " \
                       'the refresh rate and the playlist decide.', learn_more: LEARN_MORE }
          end
        end

        def offending_fields = source.custom_field_definitions.select { refresh_rate_field?(it) }

        private

        def refresh_rate_field?(field)
          return false unless "#{field['keyname'].to_s.tr('_', ' ')} #{field['name']}".match?(NAME)

          case field['field_type']
          when 'select' then interval_options?(field['options'])
          when 'number', 'string' then [field['keyname'], field['name'],
                                        field['description']].join(' ').match?(TIME_UNIT)
          else false
          end
        end

        def interval_options?(options)
          labels = Array(options).map { it.is_a?(Hash) ? it.keys.first.to_s : it.to_s }
          labels.count { it.match?(INTERVAL_OPTION) } >= 2
        end
      end
    end
  end
end
