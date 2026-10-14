# frozen_string_literal: true

require 'mini_magick'
require 'tempfile'

module TRMNLP
  module Testing
    # Which candidate pairs of text share inked pixels, as Firefox draws them.
    class TextInk
      MIN_SHARED_INK_PIXELS = 4
      TEXT_GROUP_ATTRIBUTE = 'data-trmnlp-text'
      INK_ATTRIBUTE = 'data-trmnlp-ink'
      HIDE_TEXT_STYLE = <<~CSS.freeze
        .view, .view * { color: transparent !important; -webkit-text-fill-color: transparent !important;
                         -webkit-text-stroke-width: 0 !important; text-shadow: none !important; }
        .view [#{INK_ATTRIBUTE}="black"] { color: #000 !important; -webkit-text-fill-color: #000 !important; }
        .view [#{INK_ATTRIBUTE}="white"] { color: #fff !important; -webkit-text-fill-color: #fff !important; }
      CSS

      def initialize(driver)
        @driver = driver
        @masks = {}
      end

      # candidates: { 'texts' => [group, group], 'names' => String, 'region' => { left, top, width, height } }.
      def overlapping(candidates)
        return [] if candidates.empty?

        hide_text
        candidates.select { shared_pixels(it) >= MIN_SHARED_INK_PIXELS }.map { it['names'] }.uniq
      ensure
        show_text
      end

      private

      def shared_pixels(candidate)
        one, other = candidate['texts'].map { mask(it) }
        one.shared_with(other, candidate['region'])
      end

      # One byte per pixel of the screen, above zero where the text inks.
      Mask = Data.define(:width, :height, :pixels) do
        def shared_with(other, region)
          left, top = region.values_at('left', 'top').map { it.floor.clamp(0..) }
          right = (region['left'] + region['width']).ceil.clamp(..width)
          bottom = (region['top'] + region['height']).ceil.clamp(..height)
          (top...bottom).sum { |row| (left...right).count { inked?(it, row) && other.inked?(it, row) } }
        end

        def inked?(column, row) = pixels.getbyte((row * width) + column).positive?
      end

      # Where the group inks more than half a pixel: the difference of a black and a white screenshot.
      def mask(group)
        @masks[group] ||= begin
          black, white = %w[black white].map { screenshot_with(group, it) }
          Tempfile.create(['text-ink', '.pgm']) do |pgm|
            MiniMagick.convert do |convert|
              convert << black.path << white.path << '-alpha' << 'off' << '-compose' << 'difference' << '-composite'
              convert << '-separate' << '-evaluate-sequence' << 'max' << '-threshold' << '50%' << '-depth' << '8'
              convert << pgm.path
            end
            parse_pgm(File.binread(pgm.path))
          end
        ensure
          [black, white].compact.each(&:close!)
        end
      end

      # A binary PGM: "P5", width, height and the largest value, then one byte per pixel.
      def parse_pgm(data)
        header = data.match(/\AP5\s+(\d+)\s+(\d+)\s+\d+\s/)
        Mask.new(width: header[1].to_i, height: header[2].to_i, pixels: data.byteslice(header.end(0)..))
      end

      def screenshot_with(group, color)
        run_on_group_elements(group, "el.setAttribute('#{INK_ATTRIBUTE}', '#{color}')")
        Tempfile.new(['text-ink', '.png']).tap { @driver.save_screenshot(it.path) }
      ensure
        run_on_group_elements(group, "el.removeAttribute('#{INK_ATTRIBUTE}')")
      end

      def run_on_group_elements(group, statement)
        selector = "[#{TEXT_GROUP_ATTRIBUTE}=\"#{group}\"]"
        @driver.execute_script("document.querySelectorAll('#{selector}').forEach((el) => #{statement})")
      end

      def hide_text
        @driver.execute_script(<<~JS, HIDE_TEXT_STYLE)
          const style = document.createElement('style');
          style.id = 'trmnlp-text-ink';
          style.textContent = arguments[0];
          document.head.appendChild(style);
        JS
      end

      def show_text
        @driver.execute_script("document.getElementById('trmnlp-text-ink')?.remove(); " \
                               "document.querySelectorAll('[#{TEXT_GROUP_ATTRIBUTE}]')" \
                               ".forEach((el) => el.removeAttribute('#{TEXT_GROUP_ATTRIBUTE}'))")
      end
    end
  end
end
