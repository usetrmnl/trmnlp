# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Recipe review asks for a contact that is not Discord, because not every
      # user has access to Discord.
      class AuthorContactMethod < Check
        MESSAGE = 'Add an email address, web link or GitHub link to the author_bio custom field, ' \
                  'so users can reach you with questions or issues. A Discord link alone is not enough.'
        LEARN_MORE = 'https://help.trmnl.com/en/articles/10513740-custom-plugin-form-builder#h_02dd8f84a9'
        CONTACT_KEYS = %w[email_address github_url learn_more_url description].freeze
        CONTACT_PATTERN = %r{[^\s@]+@[^\s@]+\.\w+|https?://\S+}

        private

        def pass?
          author_bio = source.custom_field_definitions.find { it['field_type'] == 'author_bio' }
          return false unless author_bio

          author_bio.values_at(*CONTACT_KEYS).join(' ').scan(CONTACT_PATTERN).any? { !it.match?(/discord/i) }
        end
      end
    end
  end
end
