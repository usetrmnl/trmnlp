# frozen_string_literal: true

require 'trmnl/liquid'

module TRMNLP
  # Mirrors core's config/initializers/trmnl_liquid_qr_code.rb: a white quiet zone inside the code's size.
  module QrCode
    QUIET_ZONE_MODULES = 4

    def qr_code(data, size = 11, level = '', view = 'responsive')
      svg = super
      side_length = svg[/<rect width="(\d+)"/, 1]
      return svg unless side_length

      border = size * QUIET_ZONE_MODULES
      box = side_length.to_i + (2 * border)
      sizing = %(width="#{side_length}" height="#{side_length}")
      sizing += ' style="max-width:100%;height:auto"' if view == 'responsive'
      svg.sub(/ (?:viewBox="[^"]*"|width="\d+" height="\d+")/, '')
         .sub('<svg ', %(<svg #{sizing} viewBox="-#{border} -#{border} #{box} #{box}" ))
         .sub(%r{<rect [^>]*?(?=/>)}, %(<rect width="#{box}" height="#{box}" x="-#{border}" y="-#{border}" fill="#fff"))
    end
  end
end

TRMNL::Liquid::Filters.prepend(TRMNLP::QrCode)
