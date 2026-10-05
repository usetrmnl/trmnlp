# frozen_string_literal: true

require 'erb'
require 'fileutils'
require 'json'
require 'rspec/core'

module TRMNLP
  module Testing
    # What `trmnlp test --report DIR` writes: every example with each screen it rendered (the PNG, the boxes
    # of everything drawn, the page's problems) and each transform it ran, as DIR/index.html and
    # DIR/report.json. Under GitHub Actions the counts and failures go to the step summary too.
    class Report
      TEMPLATE = File.expand_path('report.html.erb', __dir__)
      OUTLINES_SCRIPT = <<~JS
        (() => [...document.querySelectorAll('.view *')].slice(0, 3000).map((el) => {
          const box = el.getBoundingClientRect();
          return { tag: el.tagName.toLowerCase(), class: String(el.className.baseVal ?? el.className),
                   x: box.x, y: box.y, w: box.width, h: box.height };
        }).filter((box) => box.w > 0 && box.h > 0))()
      JS

      class << self
        attr_accessor :current
      end

      def initialize(dir)
        @dir = "#{dir}#{ENV.fetch('TEST_ENV_NUMBER', '')}" # parallel_tests: report, report2, report3...
        @examples = {}
        @images = 0
      end

      def record_screen(screen)
        entry&.fetch(:screens)&.push(
          label: "#{screen.device.name} · #{screen.view}", width: screen.device.width, height: screen.device.height,
          image: copy_image(screen.png_path), outlines: screen.evaluate(OUTLINES_SCRIPT), problems: screen.problems
        )
      end

      def record_run(run)
        return unless run.duration_ms

        entry&.fetch(:runs)&.push(duration_ms: run.duration_ms, max_memory_mb: run.max_memory_mb, error: run.error,
                                  requests: run.requests.map { it.slice(:method, :url, :status, :via, :aborted) })
      end

      def example_passed(notification) = finish(notification.example, 'passed')
      def example_pending(notification) = finish(notification.example, 'pending')
      def example_failed(notification) = finish(notification.example, 'failed', notification.example.exception&.message)

      def close(_notification)
        FileUtils.mkdir_p(@dir)
        File.write(File.join(@dir, 'report.json'), JSON.pretty_generate(examples: examples))
        File.write(File.join(@dir, 'index.html'), ERB.new(File.read(TEMPLATE)).result(binding))
        write_step_summary if ENV['GITHUB_STEP_SUMMARY']
      end

      private

      def examples = @examples.values

      def entry(example = RSpec.current_example)
        return unless example

        @examples[example.id] ||= { description: example.full_description, location: example.location,
                                    status: 'running', message: nil, screens: [], runs: [] }
      end

      def finish(example, status, message = nil) = entry(example).merge!(status:, message:)

      def copy_image(path)
        name = "images/#{@images += 1}.png"
        FileUtils.mkdir_p(File.join(@dir, 'images'))
        File.binwrite(File.join(@dir, name), File.binread(path)) # not cp, which keeps the screen's private 0600 mode
        name
      end

      def count(status) = examples.count { it[:status] == status }

      def write_step_summary
        counts = "#{count('passed')} passed, #{count('failed')} failed, #{count('pending')} pending, " \
                 "#{examples.sum { it[:screens].size }} screens"
        lines = ["### trmnlp test\n", "#{counts}\n"]
        examples.select { it[:status] == 'failed' }.each { lines << "- ❌ #{it[:description]} (`#{it[:location]}`)" }
        File.write(ENV.fetch('GITHUB_STEP_SUMMARY'), "#{lines.join("\n")}\n", mode: 'a')
      end

      def h(text) = ERB::Util.html_escape(text.to_s)
    end
  end
end
