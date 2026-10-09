# frozen_string_literal: true

require 'yaml'

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports classes in the Framework's own families that the plugin's release does
      # not define, such as `value--medium`. They match no rule, so they do nothing.
      class FrameworkClassesExist < Check
        FAMILY_PATTERN = /\A(?:value|label|title|description|text)--/
        DATA_PATH = File.expand_path('../../../../db/data/framework_classes.yml', __dir__)

        # Release number => the family classes its plugins.css defines, from that release until the next one listed.
        CLASSES_BY_RELEASE = YAML.load_file(DATA_PATH).transform_keys { Gem::Version.new(it) }.sort.freeze

        def issues
          (used_classes - release_classes).map do |name|
            { message: "'#{name}' is not a class in Framework v#{source.framework_version}, so it has no effect. " \
                       'Check the name in the Framework docs.' }
          end
        end

        private

        def used_classes
          source.html_fragments.values.flat_map { it.css('[class]').flat_map { it['class'].split } }
                .map { it.split(':').last.to_s }
                .select { it.match?(FAMILY_PATTERN) && !it.include?('{{') }
                .uniq
        end

        def release_classes
          version = Gem::Version.new(source.framework_version.number)
          CLASSES_BY_RELEASE.select { |release, _| release <= version }.last.last
        end
      end
    end
  end
end
