# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports separate latitude and longitude fields in settings.yml. One
      # lat_lon field asks for both, and lets the user pick a place on a map.
      class CoordinatesUseLatLon < Check
        LATITUDE_WORDS = %w[lat latitude].freeze
        LONGITUDE_WORDS = %w[lon lng long longitude].freeze
        LEARN_MORE = 'https://help.trmnl.com/en/articles/10513740-custom-plugin-form-builder#h_07a70ff721'

        def issues
          # A keyname with both words (lat_lng) is one field, so it never pairs with itself.
          latitude = keynames_with(LATITUDE_WORDS) - keynames_with(LONGITUDE_WORDS)
          longitude = keynames_with(LONGITUDE_WORDS) - keynames_with(LATITUDE_WORDS)
          return [] if latitude.empty? || longitude.empty?

          fields = (latitude + longitude).map { "'#{it}'" }.join(' and ')
          [{ message: "Form fields #{fields} ask for one location. Use one field with field_type 'lat_lon'.",
             learn_more: LEARN_MORE }]
        end

        private

        def keynames_with(words) = keynames.select { |keyname| words.intersect?(words_in(keyname)) }

        def keynames
          source.custom_field_definitions.reject { |field| field['field_type'] == 'lat_lon' }
                .map { |field| field['keyname'].to_s }
        end

        # home_lat, homeLat and home-lat all give %w[home lat].
        def words_in(keyname) = keyname.gsub(/([a-z\d])([A-Z])/, '\1_\2').downcase.split(/[^a-z\d]+/)
      end
    end
  end
end
