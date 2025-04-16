require 'thor/core_ext/hash_with_indifferent_access'

require_relative '../context'

module TRMNLP
  module Commands
    class Base
      include Thor::CoreExt

      def initialize(options = HashWithIndifferentAccess.new)
        @options = HashWithIndifferentAccess.new(options)
        @context = Context.new(@options.dir)
      end

      def call
        raise NotImplementedError
      end

      protected

      attr_accessor :options, :context

      def config = context.config
      def paths = context.paths

      def authenticate!
        raise Error, "please run `trmnlp login`" unless config.app.logged_in?
      end

      def output(message)
        puts(message) unless options.quiet?
      end

      def prompt(message)
        print message
        $stdin.gets.chomp
      end
    end
  end
end