# frozen_string_literal: true

require 'capybara'
require 'delegate'
require 'nokogiri'

module TRMNLP
  module Testing
    # A rendered view, as Firefox drew it. Capybara's finders and matchers (have_text, have_css, within...)
    # work on the DOM after the Framework's scripts ran; #box, #evaluate and #overflowing ask the live page.
    class Screen < SimpleDelegator
      Box = Data.define(:left, :top, :right, :bottom, :width, :height)

      # Every element drawn past the screen's edge or cut off inside a box that hides its overflow, by more
      # than `tolerance` pixels. A font's own box is taller than a tight line (line-height: 1, say), and the
      # part of it that hangs under the line is empty, so that much is not counted as cut off.
      OVERFLOW_SCRIPT = <<~JS
        const [tolerance, ignored] = arguments;
        const screen = document.documentElement.getBoundingClientRect();
        const describe = (el) => el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') +
          (el.classList.length ? '.' + [...el.classList].join('.') : '');
        const range = document.createRange();
        const hang = (el) => {
          const lineHeight = parseFloat(getComputedStyle(el).lineHeight);
          if (Number.isNaN(lineHeight)) return 0;
          const heights = [...el.childNodes].filter((node) => node.nodeType === 3 && node.data.trim())
            .flatMap((node) => { range.selectNodeContents(node); return [...range.getClientRects()]; })
            .map((rect) => rect.height);
          return Math.max(0, Math.ceil((Math.max(0, ...heights) - lineHeight) / 2));
        };
        const cutBelow = (el) => {
          const over = el.scrollHeight - el.clientHeight;
          if (over <= tolerance) return false;
          const fonts = [el, ...el.querySelectorAll('*')].map(hang);
          return over > tolerance + Math.max(0, ...fonts);
        };
        return [...document.querySelectorAll('.view *')].filter((el) => {
          if (ignored && el.closest(ignored)) return false;
          const box = el.getBoundingClientRect();
          if (box.width === 0 && box.height === 0) return false;
          const outside = box.right > screen.right + tolerance || box.bottom > screen.bottom + tolerance ||
            box.left < -tolerance || box.top < -tolerance;
          const style = getComputedStyle(el);
          const clips = ['hidden', 'clip'].includes(style.overflowX) || ['hidden', 'clip'].includes(style.overflowY);
          return outside || (clips && (el.scrollWidth > el.clientWidth + tolerance || cutBelow(el)));
        }).map(describe);
      JS

      HIDDEN_MARK = 'data-trmnlp-hidden'
      # The DOM with every element Firefox does not draw marked, so Capybara's visible text is what is on screen.
      DRAWN_DOM_SCRIPT = <<~JS.freeze
        const hidden = [...document.querySelectorAll('body *')]
          .filter((el) => !el.checkVisibility({ opacityProperty: true, visibilityProperty: true }));
        hidden.forEach((el) => el.setAttribute('#{HIDDEN_MARK}', ''));
        const copy = document.documentElement.cloneNode(true);
        hidden.forEach((el) => el.removeAttribute('#{HIDDEN_MARK}'));
        copy.querySelectorAll('script, style, noscript, template').forEach((el) => el.remove());
        return copy.outerHTML;
      JS

      attr_reader :html, :device, :view, :png_path, :result, :wait_for, :wait_for_timeout

      # rubocop:disable-next Metrics/ParameterLists -- what a render produced and how to wait for it
      def initialize(html:, device:, view:, browser:, result:, wait_for: nil, wait_for_timeout: 5)
        @html = html
        @wait_for = wait_for
        @wait_for_timeout = wait_for_timeout
        @device = device
        @view = view
        @browser = browser
        @result = result
        @png_path = browser.capture(self)
        super(Capybara.string(drawn_dom(browser.on(self) { it.execute_script(DRAWN_DOM_SCRIPT) })))
      end

      def box(selector)
        rect = evaluate("(() => { const el = document.querySelector(#{selector.to_json}); " \
                        'return el && el.getBoundingClientRect().toJSON(); })()')
        raise TestingError, "No element matches #{selector.inspect} on the #{view} view" unless rect

        Box.new(**rect.slice('left', 'top', 'right', 'bottom', 'width', 'height').transform_keys(&:to_sym))
      end

      def evaluate(expression) = @browser.on(self) { it.execute_script("return (#{expression});") }

      # tolerance: pixels an element may overflow by; ignore: a selector (or several) whose elements, and
      # everything inside them, are left out.
      def overflowing(tolerance: 1, ignore: nil)
        ignored = Array(ignore).join(', ')
        @browser.on(self) { it.execute_script(OVERFLOW_SCRIPT, tolerance, ignored.empty? ? nil : ignored) }
      end

      # Script errors, unhandled rejections, console.error lines and files that failed to load.
      def problems = evaluate('window.__trmnlpProblems || []')

      def png_bytes = File.binread(png_path)

      def drawn_dom(source)
        document = Nokogiri::HTML(source)
        document.css("[#{HIDDEN_MARK}]").each { it['hidden'] = 'hidden' }
        document.to_html
      end

      def inspect = "#<#{self.class.name} #{device.name} #{view}>"
    end
  end
end
