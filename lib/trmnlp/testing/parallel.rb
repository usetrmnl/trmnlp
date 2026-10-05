# frozen_string_literal: true

require 'json'
require 'rspec/core'
require 'tmpdir'

require_relative 'report'

module TRMNLP
  module Testing
    # `trmnlp test --workers N`: the examples dealt out over N processes, each with a Firefox of its own.
    # RSpec lists the examples first; every worker then runs its share by id, prints a mark per example and
    # leaves its results in a file. The failures, the counts and the report are put together at the end.
    class Parallel
      # A worker's only output: a mark per example, as RSpec's progress formatter prints them.
      class Marks
        RSpec::Core::Formatters.register self, :example_passed, :example_failed, :example_pending

        def initialize(output) = @output = output
        def example_passed(_notification) = mark('.')
        def example_failed(_notification) = mark('F')
        def example_pending(_notification) = mark('*')

        private

        def mark(text)
          @output.print(text)
          @output.flush
        end
      end

      def self.available? = Process.respond_to?(:fork)

      def initialize(paths:, workers:, helpers:, report_dir: nil, output: $stdout)
        @paths = paths
        @workers = workers
        @helpers = helpers
        @report_dir = report_dir
        @output = output
      end

      # True when every example passed. nil when RSpec could not list the examples (a spec that does not
      # load, say), or there are too few to share out: the caller then runs them in this process.
      def call
        Dir.mktmpdir('trmnlp-workers-') do |dir|
          ids = example_ids(File.join(dir, 'examples.json'))
          next nil if ids.nil? || ids.size < 2

          shares = deal(ids)
          started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
          statuses = run_workers(shares, dir)
          results = shares.each_index.flat_map { examples_in(result_file(dir, it)) }
          report(results, ids, Process.clock_gettime(Process::CLOCK_MONOTONIC) - started, shares.size)
          combine_reports(shares.size, ids)
          statuses.all?(&:success?) && results.none? { it['status'] == 'failed' } && results.size == ids.size
        end
      end

      private

      def example_ids(file)
        status = in_fork do
          RSpec::Core::Runner.run(['--require', @helpers, '--dry-run', '--format', 'json', '--out', file, *@paths],
                                  File::NULL, File::NULL)
        end
        return nil unless status.success?

        JSON.parse(File.read(file)).fetch('examples').map { it['id'] }
      end

      def deal(ids)
        shares = Array.new([@workers, ids.size].min) { [] }
        ids.each_with_index { |id, index| shares[index % shares.size] << id }
        shares
      end

      def run_workers(shares, dir)
        pids = shares.each_with_index.map do |ids, index|
          fork do
            ENV[Report::DIR_ENV_KEY] = part_dir(index) if @report_dir
            ENV[Report::PART_ENV_KEY] = '1'
            exit RSpec::Core::Runner.run(['--require', @helpers, '--format', Marks.name, '--format', 'json',
                                          '--out', result_file(dir, index), *ids])
          end
        end
        pids.map { Process.wait2(it).last }
      end

      def in_fork(&)
        Process.wait2(fork { exit(yield) }).last
      end

      def result_file(dir, index) = File.join(dir, "worker-#{index}.json")

      def part_dir(index) = File.join(@report_dir, ".worker-#{index}")

      def examples_in(file) = File.exist?(file) ? JSON.parse(File.read(file)).fetch('examples', []) : []

      def report(results, ids, seconds, workers)
        results = results.sort_by { ids.index(it['id']) || ids.size }
        failed = results.select { it['status'] == 'failed' }
        @output.puts
        report_failures(failed)
        @output.puts "\nFinished in #{seconds.round(2)} seconds (#{workers} workers)"
        @output.puts counts(results, ids, failed)
        return if failed.empty?

        @output.puts "\nFailed examples:\n\n"
        failed.each { @output.puts "rspec #{it['file_path']}:#{it['line_number']} # #{it['full_description']}" }
      end

      def report_failures(failed)
        @output.puts "\nFailures:" unless failed.empty?
        failed.each_with_index do |example, index|
          exception = example['exception'] || {}
          @output.puts "\n  #{index + 1}) #{example['full_description']}"
          @output.puts "     Failure/Error: #{exception['class']}"
          exception['message'].to_s.each_line { @output.puts "       #{it.chomp}" }
          @output.puts "     # #{example['file_path']}:#{example['line_number']}"
        end
      end

      def counts(results, ids, failed)
        pending = results.count { it['status'] == 'pending' }
        missing = ids.size - results.size
        line = "#{results.size} example#{'s' unless results.size == 1}, " \
               "#{failed.size} failure#{'s' unless failed.size == 1}"
        line += ", #{pending} pending" if pending.positive?
        line += ", #{missing} not run (a worker stopped early)" if missing.positive?
        line
      end

      def combine_reports(workers, ids)
        return unless @report_dir

        Report.combine(Array.new(workers) { part_dir(it) }, into: @report_dir, order: ids)
      end
    end
  end
end
