# frozen_string_literal: true

require 'json'

module TRMNLP
  module OAuth
    class TokenStore
      def initialize(path)
        @path = path
      end

      def read
        return nil unless path.exist?

        TokenBundle.from_h(JSON.parse(path.read))
      end

      def write(bundle)
        path.dirname.mkpath
        path.write(JSON.generate(bundle.to_h))
        path.chmod(0o600)
        bundle
      end

      def clear
        path.delete if path.exist?
      end

      private

      attr_reader :path
    end
  end
end
