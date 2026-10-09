# frozen_string_literal: true

require 'yaml'

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports classes in the Framework's own families that the plugin's release does
      # not define, such as `value--medium`. They match no rule, so they do nothing.
      class FrameworkClassesExist < Check
        FAMILY_PATTERN = /\A(?:value|label|title|description|text|content)--/
        DATA_PATH = File.expand_path('../../../../db/data/framework_classes.yml', __dir__)
        LEARN_MORE = 'https://trmnl.com/framework/docs/element_sizes'
        # Smallest to largest. Each family has its own subset, and the same name is a different size in each.
        # No family has `medium`, but it is the name people reach for between small and large.
        SIZES = %w[xxsmall xsmall small base medium large xlarge xxlarge xxxlarge mega giga tera peta].freeze

        # Release number => the family classes its plugins.css defines, from that release until the next one listed.
        CLASSES_BY_RELEASE = YAML.load_file(DATA_PATH).transform_keys { Gem::Version.new(it) }.sort.freeze

        def issues
          classes = release_classes
          (used_classes - classes).map do |name|
            missing = "'#{name}' is not a class in Framework v#{source.framework_version}, so it has no effect."
            sizes = sizes_of(name, classes)
            next { message: "#{missing} Check the name in the Framework docs." } if sizes.empty?

            { message: "#{missing} Its sizes are #{sizes.join(', ')}.", learn_more: LEARN_MORE }
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

        # The family's sizes in this release, when the class names a size; empty otherwise.
        def sizes_of(name, classes)
          family, size = name.split('--', 2)
          return [] unless SIZES.include?(size)

          SIZES.map { "#{family}--#{it}" } & classes
        end
      end
    end
  end
end
