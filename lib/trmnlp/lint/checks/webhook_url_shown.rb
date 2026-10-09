# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Recipe review asks a webhook recipe to show each install its own
      # webhook URL, so the user can copy it into the service that pushes data.
      class WebhookUrlShown < Check
        MESSAGE = 'Add a custom field with field_type copyable_webhook_url, so people who install this webhook ' \
                  'recipe can copy their webhook URL. TRMNL fills it in with the URL of each install.'
        LEARN_MORE = 'https://help.trmnl.com/en/articles/10513740-custom-plugin-form-builder'

        private

        def pass?
          source.settings['strategy'] != 'webhook' ||
            source.custom_field_definitions.any? { it['field_type'] == 'copyable_webhook_url' }
        end
      end
    end
  end
end
