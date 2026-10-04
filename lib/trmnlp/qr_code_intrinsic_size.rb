# frozen_string_literal: true

require 'trmnl/liquid'

module TRMNLP
  # Mirrors core's config/initializers/trmnl_liquid_qr_code_intrinsic_size.rb: a view box alone
  # gives the code no size of its own, so it renders at zero width in a shrink-to-fit container.
  module QrCodeIntrinsicSize
    def qr_code(data, size = 11, level = '', view = 'responsive')
      svg = super
      root_element = svg[/<svg[^>]*>/].to_s
      return svg if root_element.include?('width=')

      side_length = root_element[/viewBox="0 0 (\d+)/, 1]
      return svg unless side_length

      svg.sub('<svg ', %(<svg width="#{side_length}" height="#{side_length}" style="max-width:100%;height:auto" ))
    end
  end
end

TRMNL::Liquid::Filters.prepend(TRMNLP::QrCodeIntrinsicSize)
