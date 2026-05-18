# frozen_string_literal: true

require_relative '../context'
require_relative '../form_field'
require_relative '../reporter'

module TRMNLP
  module Commands
    class Base
      def self.run(input, *)
        options = options_from(input)
        reporter = Reporter.new(quiet: options.quiet)
        new(context: Context.new(options.dir, reporter:), options:, reporter:).call(*)
      end

      # NOTE: Thor only includes flags the user actually passed, but Data.define
      # requires every member. We pad missing members with nil so partial Thor
      # hashes round-trip into a fully-populated typed Options struct.
      def self.options_from(input)
        return input if input.is_a?(self::Options)

        hash = input.to_h.transform_keys(&:to_sym)
        self::Options.new(**self::Options.members.to_h { [it, hash[it]] })
      end

      def initialize(context:, options:, reporter: nil)
        raise ArgumentError, "options must be a #{self.class}::Options" unless options.is_a?(self.class::Options)

        @context = context
        @options = options
        @reporter = reporter || Reporter.new(quiet: options.quiet)
      end

      def call
        raise NotImplementedError
      end

      protected

      attr_accessor :options, :context, :reporter

      def config = context.config
      def paths = context.paths

      def authenticate!
        raise NotLoggedIn, 'please run `trmnlp login`' unless config.app.logged_in?
      end

      # Non-blocking: warn about malformed settings.yml custom_fields so a
      # plugin author notices before the field misbehaves in production.
      def report_form_field_warnings
        FormField.validate_all(config.plugin.custom_field_definitions).each do |warning|
          reporter.info(reporter.yellow("warning: settings.yml custom_fields — #{warning}"))
        end
      end

      def prompt(message)
        print message
        $stdin.gets.chomp
      end
    end
  end
end
