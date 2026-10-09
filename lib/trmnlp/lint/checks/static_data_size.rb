# frozen_string_literal: true

require 'json'

require_relative '../check'
require_relative '../../renderer'

module TRMNLP
  module Lint
    module Checks
      # TRMNL refuses to save static data over its merge variable limit. trmnlp only
      # measures the data a render receives, which a transform can shrink, so a
      # recipe whose transform trims its static data renders here and fails on upload.
      class StaticDataSize < Check
        MAX_BYTES = Renderer::MAX_MERGE_VARIABLES_KB * 1024

        def issues
          size = JSON.generate(source.static_data).bytesize
          return [] if size <= MAX_BYTES

          [{ message: "static_data is #{size} bytes; TRMNL rejects static data over " \
                      "#{Renderer::MAX_MERGE_VARIABLES_KB} KB." }]
        end
      end
    end
  end
end
