# frozen_string_literal: true

require 'yaml'

require_relative '../check'
require_relative 'framework_classes_exist'

module TRMNLP
  module Lint
    module Checks
      # Reports a Framework class behind screen prefixes that the plugin's release does not
      # define for it, such as `xl:value--large` or `dark:value--large`. The class matches no
      # rule, so it does nothing. Classes the release lacks entirely are left to FrameworkClassesExist.
      class FrameworkPrefixesExist < Check
        PREFIXED_PATTERN = /\A(?<prefix>.+):(?<name>(?:value|label|title|description|text|content)--.+)\z/
        DATA_PATH = File.expand_path('../../../../db/data/framework_prefixes.yml', __dir__)
        LEARN_MORE = 'https://trmnl.com/framework/docs/responsive'

        # Release number => the prefixes its plugins.css defines and the classes each covers,
        # from that release until the next one listed.
        VARIANTS_BY_RELEASE = YAML.load_file(DATA_PATH).transform_keys { Gem::Version.new(it) }.sort.freeze

        def issues
          prefixed_classes.filter_map do |full_name, prefix, name|
            next unless release_classes.include?(name)

            next if covers?(prefix, name)

            { message: "'#{full_name}' has no effect: #{reason(prefix, name)}", learn_more: LEARN_MORE }
          end
        end

        private

        # A Liquid tag splits into several words, so any word with a brace or percent sign is skipped.
        def prefixed_classes
          source.html_fragments.values.flat_map { it.css('[class]').flat_map { it['class'].split } }
                .grep_v(/[{}%]/)
                .uniq
                .filter_map { |full_name| (match = full_name.match(PREFIXED_PATTERN)) && [full_name, *match.captures] }
        end

        def reason(prefix, name)
          version = "Framework v#{source.framework_version}"
          return "#{name} has no '#{prefix}:' variant in #{version}." if families_by_prefix.key?(prefix)

          reordered = families_by_prefix.keys.find do |known|
            known.split(':').sort == prefix.split(':').sort && covers?(known, name)
          end
          return "#{version} has no '#{prefix}:' prefix. Write it as '#{reordered}:#{name}'." if reordered

          "#{version} has no '#{prefix}:' prefix."
        end

        # A family is covered as `all` its classes, all `except` some, or `only` some.
        def covers?(prefix, name)
          coverage = families_by_prefix.dig(prefix, name.split('--').first)
          case coverage
          when 'all' then true
          when Hash then coverage.key?('except') ? !coverage['except'].include?(name) : coverage['only'].include?(name)
          else false
          end
        end

        def families_by_prefix
          @families_by_prefix ||= in_release(VARIANTS_BY_RELEASE).each_with_object({}) do |variant, prefixes|
            variant['prefixes'].each { prefixes[it] = variant['families'] }
          end
        end

        def release_classes = @release_classes ||= in_release(FrameworkClassesExist::CLASSES_BY_RELEASE)

        def in_release(lists)
          version = Gem::Version.new(source.framework_version.number)
          lists.select { |release, _| release <= version }.last.last
        end
      end
    end
  end
end
