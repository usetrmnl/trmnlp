# frozen_string_literal: true

require 'capybara'
require 'delegate'
require 'nokogiri'

require_relative 'qr_scanner'

module TRMNLP
  module Testing
    # A rendered view, as Firefox drew it. Capybara's finders and matchers (have_text, have_css, within...)
    # work on the DOM after the Framework's scripts ran; #box, #evaluate and #overflowing ask the live page.
    class Screen < SimpleDelegator
      Box = Data.define(:left, :top, :right, :bottom, :width, :height)

      # Every element drawn past the screen's edge, and every box that cuts a child box or a glyph's ink.
      OVERFLOW_SCRIPT = <<~JS
        const screen = document.documentElement.getBoundingClientRect();
        const describe = (el) => el.tagName.toLowerCase() + (el.id ? '#' + el.id : '') +
          (el.classList.length ? '.' + [...el.classList].join('.') : '');
        const clips = (el) => getComputedStyle(el).overflow !== 'visible';
        const truncatesOnPurpose = (style) => style.textOverflow === 'ellipsis' || style.webkitLineClamp !== 'none';
        const drawn = (rect) => rect.width > 0 || rect.height > 0;
        const insideTruncation = (el) => {
          for (let parent = el.parentElement; parent; parent = parent.parentElement) {
            if (truncatesOnPurpose(getComputedStyle(parent))) return true;
          }
          return false;
        };
        const clippedOnlyBy = (node, el) => {
          for (let parent = node.parentElement; parent !== el; parent = parent.parentElement) {
            if (clips(parent)) return false;
          }
          return true;
        };
        const inlineBox = (el) => getComputedStyle(el).display === 'inline' &&
          !(el instanceof HTMLImageElement || el instanceof SVGSVGElement || el instanceof HTMLCanvasElement);
        const textMeasuringContext = document.createElement('canvas').getContext('2d');
        const glyphInk = (glyph, rect) => {
          const metrics = textMeasuringContext.measureText(glyph);
          const scale = rect.height / (metrics.fontBoundingBoxAscent + metrics.fontBoundingBoxDescent);
          const baseline = rect.top + metrics.fontBoundingBoxAscent * scale;
          return { left: rect.left - metrics.actualBoundingBoxLeft * scale,
                   right: rect.left + metrics.actualBoundingBoxRight * scale,
                   top: baseline - metrics.actualBoundingBoxAscent * scale,
                   bottom: baseline + metrics.actualBoundingBoxDescent * scale };
        };
        const glyphRects = (el) => {
          const found = [];
          const range = document.createRange();
          const walker = document.createTreeWalker(el, NodeFilter.SHOW_TEXT);
          for (let node = walker.nextNode(); node; node = walker.nextNode()) {
            if (!node.data.trim() || !clippedOnlyBy(node, el) || node.parentElement instanceof SVGElement) continue;
            const style = getComputedStyle(node.parentElement);
            textMeasuringContext.font = `${style.fontStyle} ${style.fontWeight} ${style.fontSize} ${style.fontFamily}`;
            for (let start = 0; start < node.data.length;) {
              const end = start + String.fromCodePoint(node.data.codePointAt(start)).length;
              const glyph = node.data.slice(start, end);
              if (glyph.trim()) {
                range.setStart(node, start);
                range.setEnd(node, end);
                [...range.getClientRects()].filter(drawn).forEach((rect) => found.push(glyphInk(glyph, rect)));
              }
              start = end;
            }
          }
          return found;
        };
        const cutsChildOrGlyph = (el) => {
          const box = el.getBoundingClientRect();
          const left = box.left + el.clientLeft;
          const top = box.top + el.clientTop;
          const crossesBoxEdge = (rect) => rect.left < left - 1 || rect.top < top - 1 ||
            rect.right > left + el.clientWidth + 1 || rect.bottom > top + el.clientHeight + 1;
          const children = [...el.querySelectorAll('*')].filter((child) => clippedOnlyBy(child, el) && !inlineBox(child))
            .map((child) => child.getBoundingClientRect()).filter(drawn);
          return children.some(crossesBoxEdge) || glyphRects(el).some(crossesBoxEdge);
        };
        return [...document.querySelectorAll('.view *')].filter((el) => {
          const box = el.getBoundingClientRect();
          if (!drawn(box) || insideTruncation(el)) return false;
          const outside = box.right > screen.right + 1 || box.bottom > screen.bottom + 1 || box.left < -1 || box.top < -1;
          const style = getComputedStyle(el);
          const overflows = el.scrollWidth > el.clientWidth + 1 || el.scrollHeight > el.clientHeight + 1;
          return outside || (clips(el) && !truncatesOnPurpose(style) && overflows && cutsChildOrGlyph(el));
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

      # The text of each QR code that scans in the PNG, so on what the device shows; within: a selector
      # limits the scan to that element.
      def qr_codes(within: nil) = QrScanner.new(png_path, area: within && box(within)).texts

      def drawn_dom(source)
        document = Nokogiri::HTML(source)
        document.css("[#{HIDDEN_MARK}]").each { it['hidden'] = 'hidden' }
        document.to_html
      end

      def inspect = "#<#{self.class.name} #{device.name} #{view}>"
    end
  end
end
