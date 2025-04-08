# frozen_string_literal: true

module TRMNLP; end

require_relative "trmnlp/config"
require_relative "trmnlp/context"
require_relative "trmnlp/version"

module TRMNLP
  VIEWS = %w{full half_horizontal half_vertical quadrant}

  class Error < StandardError; end
end