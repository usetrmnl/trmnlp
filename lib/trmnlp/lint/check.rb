# frozen_string_literal: true

module TRMNLP
  module Lint
    # Base class for a single best-practice check. A subclass declares a
    # MESSAGE constant (and optionally LEARN_MORE) and implements #pass?.
    # Checks that surface a variable number of findings override #issues.
    class Check
      def initialize(source)
        @source = source
      end

      def issues
        pass? ? [] : [issue]
      end

      private

      attr_reader :source

      def pass?
        raise NotImplementedError
      end

      def issue
        learn_more = self.class.const_defined?(:LEARN_MORE) ? self.class::LEARN_MORE : nil
        { message: self.class::MESSAGE, learn_more: }.compact
      end
    end
  end
end
