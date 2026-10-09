# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Recipe review flags a plain https:// link in a custom field's description. An
      # embedded link is shorter, opens in a new tab and is plainly clickable. Review
      # skips a link without https://, which is how an example stays unlinked.
      class CustomFieldLinksEmbedded < Check
        LEARN_MORE = 'https://help.trmnl.com/en/articles/11395668-recipe-best-practices#h_d981e5e6c6'
        DESCRIPTION_KEY = /\Adescription(?:-[\w-]+)?\z/
        ANCHOR = %r{<a\b[^>]*>.*?</a>}im
        PLAIN_LINK = %r{https://[^\s<>"']*[^\s<>"'.,;:!?)]}

        def issues
          source.custom_field_definitions.flat_map do |field|
            field.select { |key, _| key.match?(DESCRIPTION_KEY) }.flat_map do |key, text|
              text.to_s.gsub(ANCHOR, '').scan(PLAIN_LINK).uniq.map { issue_for(field['keyname'], key, it) }
            end
          end
        end

        private

        def issue_for(keyname, key, url)
          { message: "Custom field '#{keyname}' #{key} has a plain link, #{url}. Embed it as " \
                     "<a href=\"#{url}\" class=\"underline\">, or remove https:// if it is only an example.",
            learn_more: LEARN_MORE }
        end
      end
    end
  end
end
