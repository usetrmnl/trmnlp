# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports bracketed Framework classes the Framework never generates, one
      # finding per class. They match no rule, so they do nothing, and nothing
      # says so: `lg:w--[192px]` leaves the element at its smaller width.
      #
      # The ranges mirror the loops in the Framework's utilities/_size.scss,
      # _gap.scss and _rounded.scss, and hold for every 3.x release's
      # plugins.css. v2 generated wider sizes, so earlier versions are skipped;
      # prefixed gaps (`md:gap--[20px]`) existed until 3.2.0. There is no
      # upstream file to sync from, so update this by hand when the Framework
      # changes, the same way db/data/form_fields.yml is kept current.
      class ArbitraryValuesInRange < Check
        # Each family as written before the bracket: `w--[Npx]`, `w--max-[Npx]`.
        SIZE_FAMILIES = %w[w-- h-- w--min- w--max- h--min- h--max-].freeze

        # family => { unit => max }. Every range starts at 0 and steps by 1.
        RANGES = SIZE_FAMILIES.to_h do |family|
          [family, { 'px' => 128, (family.start_with?('w') ? 'cqw' : 'cqh') => 100 }]
        end.merge('gap--' => { 'px' => 50 }, 'rounded--' => { 'px' => 50 }).freeze

        # `gap--[Npx]` and `rounded--[Npx]` exist only without a screen prefix.
        PREFIXABLE = SIZE_FAMILIES

        FIRST_VERSION = Gem::Version.new('3.0.0')
        UNPREFIXED_GAP_VERSION = Gem::Version.new('3.2.0')

        PATTERN = /
          (?<![\w:-])
          (?<prefix>(?:[a-z0-9-]+:)*)
          (?<family>w--min-|w--max-|h--min-|h--max-|w--|h--|gap--|rounded--)
          \[(?<value>[\d.]+)(?<unit>[a-z]+)\]
        /x

        def issues
          return [] if version < FIRST_VERSION

          source.all_markup.scan(PATTERN).uniq.filter_map do |prefix, family, value, unit|
            css_class = "#{prefix}#{family}[#{value}#{unit}]"
            reason = problem(prefix, family, value, unit)
            { message: "'#{css_class}' has no effect: #{reason}." } if reason
          end
        end

        private

        def version = @version ||= Gem::Version.new(source.framework_version.number)

        def problem(prefix, family, value, unit)
          max = RANGES.dig(family, unit)
          return "the Framework has no '#{unit}' values for '#{family}'" unless max
          return "'#{family}[Npx]' takes no screen prefix" if prefix_unsupported?(prefix, family)
          return nil if value.match?(/\A\d+\z/) && value.to_i <= max

          "the Framework generates '#{family}[N#{unit}]' from 0 to #{max} in whole numbers"
        end

        def prefix_unsupported?(prefix, family)
          !prefix.empty? && !PREFIXABLE.include?(family) &&
            (family == 'rounded--' || version >= UNPREFIXED_GAP_VERSION)
        end
      end
    end
  end
end
