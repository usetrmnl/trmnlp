# frozen_string_literal: true

require_relative 'base'
require_relative '../lint'

module TRMNLP
  module Commands
    # Runs the markup best-practice checks and reports their findings.
    class Lint < Base
      Options = Data.define(:dir, :quiet)

      def call
        context.validate!
        report
        issues.empty?
      end

      private

      def issues
        @issues ||= TRMNLP::Lint::CHECKS.flat_map { |check| check.new(source).issues }.uniq
      end

      def source
        @source ||= TRMNLP::Lint::Source.new(config:, paths:)
      end

      def report
        return reporter.info(reporter.green('✓ All checks passed!')) if issues.empty?

        reporter.info(reporter.yellow("#{issues.size} issue#{'s' if issues.size > 1} found:\n"))
        issues.each_with_index { |issue, index| report_issue(issue, index) }
        reporter.info('')
      end

      def report_issue(issue, index)
        reporter.info("  #{index + 1}. #{issue[:message]}")
        reporter.info("     Learn more: #{issue[:learn_more]}") if issue[:learn_more]
      end
    end
  end
end
