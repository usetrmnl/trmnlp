# frozen_string_literal: true

require 'faraday'
require 'uri'

module TRMNLP
  module Testing
    # Puts a page's linked stylesheets in the page itself. A page written with document.write, as TRMNL and
    # trmnlp write theirs, runs its scripts without waiting for linked stylesheets, so a script that
    # measures text (a layout solver, say) raced them and drew a different board from run to run.
    module InlineStylesheets
      LINK = /<link\b[^>]*\brel=["']stylesheet["'][^>]*>/i
      SCRIPT = %r{<script\b.*?</script>}im
      HREF = /\bhref=["'](https?:[^"']+)["']/i
      CSS_URL = /url\(\s*(['"]?)(?!data:|https?:|#)([^'")]+)\1\s*\)/i

      module_function

      def call(html)
        html.gsub(Regexp.union(SCRIPT, LINK)) do |tag|
          next tag if tag.match?(/\A<script/i)

          url = tag[HREF, 1]
          css = url && stylesheet(url)
          css ? "<style data-href=\"#{url}\">#{css}</style>" : tag
        end
      end

      # nil when the stylesheet cannot be fetched: the page keeps its link.
      def stylesheet(url)
        cache.fetch(url) do
          response = Faraday.get(url)
          cache[url] = response.success? ? absolute_urls(response.body, url) : nil
        end
      rescue Faraday::Error
        nil
      end

      def absolute_urls(css, base) = css.gsub(CSS_URL) { "url(\"#{URI.join(base, Regexp.last_match(2))}\")" }

      def cache = @cache ||= {}
    end
  end
end
