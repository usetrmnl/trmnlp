# frozen_string_literal: true

module TRMNLPreview; end

# require_relative "trmnl_preview/app"
require_relative "trmnl_preview/version"

module TRMNLPreview
  VIEWS = %w{full half_horizontal half_vertical quadrant}
  
  class Error < StandardError; end
  # Your code goes here...
end
