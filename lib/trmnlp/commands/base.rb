require_relative '../context'

module TRMNLP
  module Commands
    class Base
      def initialize(options)
        @options = options
        @context = Context.new(options.dir)
      end

      def call
        raise NotImplementedError
      end

      private

      attr_accessor :options, :context

      def config = context.config
      def paths = context.paths
    end
  end
end