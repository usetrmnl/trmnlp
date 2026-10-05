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

      # Every element drawn past the screen's edge or cut off inside a box that hides its overflow.
      OVERFLOW_SCRIPT = <<~JS
        const screen = document.documentElement.getBoundingClientRect();
        const describe = (el) => el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') +
          (el.classList.length ? '.' + [...el.classList].join('.') : '');
        return [...document.querySelectorAll('.view *')].filter((el) => {
          const box = el.getBoundingClientRect();
          if (box.width === 0 && box.height === 0) return false;
          const outside = box.right > screen.right + 1 || box.bottom > screen.bottom + 1 || box.left < -1 || box.top < -1;
          const style = getComputedStyle(el);
          const clips = ['hidden', 'clip'].includes(style.overflowX) || ['hidden', 'clip'].includes(style.overflowY);
          const cut = clips && (el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 1);
          return outside || cut;
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

      attr_reader :html, :device, :view, :result, :wait_for, :wait_for_timeout

      # rubocop:disable-next Metrics/ParameterLists -- what a render produced and how to wait for it
      def initialize(html:, device:, view:, browser:, result:, wait_for: nil, wait_for_timeout: 5)
        @html = html
        @wait_for = wait_for
        @wait_for_timeout = wait_for_timeout
        @device = device
        @view = view
        @browser = browser
        @result = result
        browser.load(self)
        super(Capybara.string(drawn_dom(browser.on(self) { it.execute_script(DRAWN_DOM_SCRIPT) })))
      end

      def box(selector)
        rect = evaluate("(() => { const el = document.querySelector(#{selector.to_json}); " \
                        'return el && el.getBoundingClientRect().toJSON(); })()')
        raise TestingError, "No element matches #{selector.inspect} on the #{view} view" unless rect

        Box.new(**rect.slice('left', 'top', 'right', 'bottom', 'width', 'height').transform_keys(&:to_sym))
      end

      def evaluate(expression) = @browser.on(self) { it.execute_script("return (#{expression});") }

      def overflowing = @browser.on(self) { it.execute_script(OVERFLOW_SCRIPT) }

      # Script errors, unhandled rejections, console.error lines and files that failed to load.
      def problems = evaluate('window.__trmnlpProblems || []')

      # The screenshot, quantized for the device. It is taken the first time it is asked for, so a test that
      # only reads the page does not wait for a picture.
      def png_path = @png_path ||= @browser.capture(self)

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
