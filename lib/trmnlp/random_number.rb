# frozen_string_literal: true

require 'securerandom'
require 'trmnl/liquid'

module TRMNLP
  # TRMNL's random_number filter, merged in trmnl-liquid but not in the 0.8.2 release trmnlp needs.
  module RandomNumber
    def random_number(_value, min = nil, max = nil)
      lower, upper = if min.nil? then [0, 100]
                     elsif max.nil? then [0, min.to_i]
                     else [min.to_i, max.to_i].minmax
                     end
      lower + SecureRandom.random_number(upper - lower + 1)
    end
  end
end

TRMNL::Liquid::Filters.include(TRMNLP::RandomNumber) unless TRMNL::Liquid::Filters.method_defined?(:random_number)
