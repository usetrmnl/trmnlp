# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # TRMNL refuses to import a settings.yml, view or transform over 100 KB, so `trmnlp push` fails.
      class FilesUnderUploadLimit < Check
        MAX_BYTES = 100 * 1024

        def issues
          source.upload_files.filter_map do |path|
            next if path.size <= MAX_BYTES

            { message: "src/#{path.basename} is #{path.size} bytes; TRMNL refuses to import a file over 100 KB." }
          end
        end
      end
    end
  end
end
