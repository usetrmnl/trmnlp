module TRMNLP
  module Commands
    class Base
      def initialize(options)
        @options = options
      end

      def call
        raise NotImplementedError
      end

      private

      attr_accessor :options
    end
  end
end