# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      # Reports <style> rules that redo what the framework does across screens: fixed font
      # sizes (no lg: scaling), hand-written line clamping and orientation reflows. CSS for
      # art, charts and SVG text is left alone.
      class NoStyleRestylingFramework < Check
        STYLE_BLOCK = %r{<style\b[^>]*>(.*?)</style>}mi
        RULE = /([^{}]*)\{([^{}]*)\}/
        FIXED_FONT_SIZE = /font-size\s*:\s*[\d.]+\s*(?:px|pt)\b/i
        SVG_OR_CHART = /(?:\A|[\s>+~,])(?:svg|text|tspan)\b|highcharts|chart/i
        KINDS = {
          font_size: ['A <style> block sets font-size in px or pt, so the text keeps one size on every screen. ' \
                      'Use the element sizes (label, value, description, title) with lg: steps.',
                      'https://trmnl.com/framework/docs/3.4/element_sizes'],
          line_clamp: ['A <style> block clamps lines with -webkit-line-clamp. Use data-clamp="N" on the element.',
                       'https://trmnl.com/framework/docs/3.4/clamp'],
          orientation: ['A <style> block reflows with @media (orientation …). ' \
                        'Use the portrait: and lg:portrait: prefixes.',
                        'https://trmnl.com/framework/docs/3.4/responsive']
        }.freeze

        def issues
          occurrences.keys.map { |kind| { message: KINDS[kind][0], learn_more: KINDS[kind][1] } }
        end

        # kind => [[path, offset], ...] for each place in a <style> block.
        def occurrences
          @occurrences ||= places.group_by(&:first).transform_values { it.map { |_, path, offset| [path, offset] } }
        end

        private

        def places
          source.markup_files.flat_map do |path, markup|
            markup.to_enum(:scan, STYLE_BLOCK).flat_map do
              start = Regexp.last_match.begin(1)
              style_block_offsets(Regexp.last_match(1)).map { |kind, offset| [kind, path, start + offset] }
            end
          end
        end

        def style_block_offsets(css)
          offsets = css.to_enum(:scan, RULE).filter_map do
            selector, declarations = Regexp.last_match.captures
            next if selector.match?(SVG_OR_CHART) || !declarations.match?(FIXED_FONT_SIZE)

            [:font_size, Regexp.last_match.begin(2) + declarations.index(FIXED_FONT_SIZE)]
          end
          offsets + pattern_offsets(css, /-webkit-line-clamp/i, :line_clamp) +
            pattern_offsets(css, /@media[^{]*orientation/i, :orientation)
        end

        def pattern_offsets(css, pattern, kind) = css.to_enum(:scan, pattern).map { [kind, Regexp.last_match.begin(0)] }
      end
    end
  end
end
