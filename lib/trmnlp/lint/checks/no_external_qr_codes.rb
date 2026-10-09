# frozen_string_literal: true

require_relative '../check'

module TRMNLP
  module Lint
    module Checks
      class NoExternalQrCodes < Check
        MESSAGE = 'Instead of an external service, please use our built-in Liquid filter for QR codes "qr_code".'
        LEARN_MORE = 'https://help.trmnl.com/en/articles/10347358-custom-plugin-filters#h_1c2c240f9e'
        QR_GENERATORS = %r{
          (?:qrserver\.com|goqr\.me|qrcode\.tec-it\.com|qrcode-monkey\.com
          |quickchart\.io/qr\b|chart\.googleapis\.com/chart\?[^"')]*\bcht=qr\b)
        }xi
        PATTERN = %r{(?:\bsrc\s*=\s*|\burl\(\s*)["']?(?:https?:)?//(?:[\w-]+\.)*#{QR_GENERATORS}}i

        private

        def pass? = !source.all_markup.match?(PATTERN)
      end
    end
  end
end
