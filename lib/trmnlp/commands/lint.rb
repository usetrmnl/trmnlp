# frozen_string_literal: true

require_relative 'base'
require_relative '../lint'
require_relative '../lint/diagnostic'
require 'json'

module TRMNLP
  module Commands
    # Runs the markup best-practice checks and reports their findings.
    class Lint < Base
      Options = Data.define(:dir, :quiet, :format) do
        def initialize(dir:, quiet:, format: 'text')
          super(dir:, quiet:, format: format || 'text')
        end
      end

      def call
        context.validate!
        report
        issues.empty?
      end

      private

      def issues
        @issues ||= checks.flat_map do |type|
          check = type.new(source)
          check.issues.map { |finding| TRMNLP::Lint::Diagnostic.new(check, source, finding).to_h }
        end.uniq
      end

      def checks
        checks_by_rule_id = TRMNLP::Lint::CHECKS.to_h { |type| [TRMNLP::Lint.rule_id(type), type] }
        unknown_rule_ids = config.project.ignored_lint_rules - checks_by_rule_id.keys
        unless unknown_rule_ids.empty?
          raise InvalidConfig, ".trmnlp.yml ignored_lint_rules has unknown rule IDs: #{unknown_rule_ids.join(', ')}. " \
                               "Known rule IDs: #{checks_by_rule_id.keys.join(', ')}"
        end

        checks_by_rule_id.except(*config.project.ignored_lint_rules).values
      end

      def source
        @source ||= TRMNLP::Lint::Source.new(config:, paths:)
      end

      def report
        return reporter.info(JSON.generate(version: 1, passed: issues.empty?, issues:)) if options.format == 'json'

        return reporter.info(reporter.green('✓ All checks passed!')) if issues.empty?

        reporter.info(reporter.yellow("#{issues.size} issue#{'s' if issues.size > 1} found:\n"))
        issues.each_with_index { |issue, index| report_issue(issue, index) }
        reporter.info('')
      end

      def report_issue(issue, index)
        reporter.info("  #{index + 1}. [#{issue[:rule_id]}] #{issue[:message]}")
        issue[:locations].each do |location|
          reporter.info("     #{location[:path]}:#{location[:line]}:#{location[:column]}")
          reporter.info("       #{location[:snippet]}") unless location[:snippet].to_s.empty?
        end
        reporter.info("     Learn more: #{issue[:learn_more]}") if issue[:learn_more]
      end
    end
  end
end
