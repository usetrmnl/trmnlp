# frozen_string_literal: true

require 'time'

require_relative 'device_models'
require_relative 'report'
require_relative 'run'
require_relative 'screen'

module TRMNLP
  module Testing
    # What a test calls as `trmnl`: the plugin in the current directory, rendered or transformed with the test's
    # inputs. Every input is optional: now:, custom_fields:, variables:, state:, previous_merge_variables:,
    # data: (skips polling), mocks:, transform: false.
    class Plugin
      # Records what goes wrong on the page, for Screen#problems; it runs before anything else in it.
      PROBLEMS_SCRIPT = <<~JS.gsub(/\s+/, ' ').strip
        (() => {
          const problems = window.__trmnlpProblems = [];
          window.addEventListener('error', (event) => {
            const source = event.target && event.target !== window && (event.target.src || event.target.href);
            problems.push(source ? `failed to load ${source}` :
              `${event.message}${event.filename ? ` (${event.filename}:${event.lineno})` : ''}`);
          }, true);
          window.addEventListener('unhandledrejection', (event) =>
            problems.push(`unhandled rejection: ${(event.reason && event.reason.message) || event.reason}`));
          const consoleError = console.error;
          console.error = (...parts) => { problems.push(`console.error: ${parts.join(' ')}`); consoleError(...parts); };
        })();
      JS
      PAGE_CLOCK_SCRIPT = '(() => { const offset = %d; const RealDate = Date; ' \
                          'class TestDate extends RealDate { constructor(...args) { args.length ? super(...args) : ' \
                          'super(RealDate.now() + offset); } static now() { return RealDate.now() + offset; } } ' \
                          'window.Date = TestDate; })();'

      def initialize(dir, browser:, authority:)
        @dir = dir
        @browser = browser
        @authority = authority
      end

      # The plugin in another folder, rendered in the same browser: a built copy, say.
      def plugin(dir) = self.class.new(File.expand_path(dir), browser: @browser, authority: @authority)

      def transform(device: 'og_plus', orientation: :landscape, now: nil, **)
        device = DeviceModels.find(device, orientation:)
        run(now, **).transform(device: device.render_params).tap { Report.current&.record_run(it) }
      end

      # A render also takes head: (markup for the page's <head>, before the Framework loads), wait_for: (a
      # JavaScript expression the page must reach before it is captured) and wait_for_timeout: (seconds).
      # rubocop:disable-next Metrics/ParameterLists -- one keyword per choice a render offers
      def render(view: 'full', device: 'og_plus', orientation: :landscape, palette: nil, dark_mode: false, theme: nil,
                 now: nil, head: nil, wait_for: nil, wait_for_timeout: 5, fresh_browser: false, **)
        device = DeviceModels.find(device, orientation:, palette:)
        classes = [device.screen_classes, ('screen--dark-mode' if dark_mode)].compact.join(' ')
        result = run(now, **).render(view:, device: device.render_params, screen_classes: classes, theme:)
        html = with_problems_trap(with_head(with_page_clock(result.html, now), head))
        browser = fresh_browser ? @browser.fresh : @browser
        Report.current&.record_run(result)
        Screen.new(html:, device:, view:, browser:, result:, wait_for:, wait_for_timeout:)
              .tap { Report.current&.record_screen(it) }
      end

      private

      def run(now, **) = Run.new(plugin: @dir, authority: @authority, now: time(now), **)

      def time(value)
        case value
        when nil then nil
        when Time then value.utc
        when Date then value.to_time.utc
        else Time.iso8601(value.to_s).utc
        end
      end

      def with_problems_trap(html) = html.sub(/<head>/i) { "<head><script>#{PROBLEMS_SCRIPT}</script>" }

      def with_head(html, head) = head ? html.sub(%r{</head>}i) { "#{head}</head>" } : html

      # Scripts in the markup see the test's time too; the page's clock then runs on from it.
      def with_page_clock(html, now)
        return html unless now

        offset = ((time(now).to_f - Time.now.to_f) * 1000).round
        html.sub(/<head>/i) { "<head><script>#{format(PAGE_CLOCK_SCRIPT, offset)}</script>" }
      end
    end
  end
end
