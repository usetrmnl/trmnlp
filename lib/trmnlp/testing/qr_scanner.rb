# frozen_string_literal: true

require 'mini_magick'
require 'nokogiri'
require 'open3'
require 'tempfile'

module TRMNLP
  module Testing
    # Reads the QR codes in a PNG the way a phone would, with zbar's `zbarimg`.
    class QrScanner
      COMMAND = 'zbarimg'
      MISSING = 'Scanning a QR code needs zbar (`brew install zbar` or `apt-get install zbar-tools`; ' \
                'already in the Docker image)'

      def initialize(path, area: nil)
        @path = path
        @area = area
      end

      # The text of every code found, in the order zbar reports them.
      def texts = @area ? cropped { scan(it) } : scan(@path)

      private

      def scan(path)
        xml, _status = Open3.capture2(COMMAND, '--quiet', '--xml', '-Sdisable', '-Sqrcode.enable', path)
        Nokogiri::XML(xml).remove_namespaces!.xpath('//symbol/data').map(&:text)
      rescue Errno::ENOENT
        raise TestingError, MISSING
      end

      def cropped
        Tempfile.create(['trmnlp-qr-', '.png']) do |file|
          MiniMagick::Image.open(@path).crop(crop_geometry).write(file.path)
          yield file.path
        end
      end

      def crop_geometry
        left = @area.left.floor
        top = @area.top.floor
        "#{@area.right.ceil - left}x#{@area.bottom.ceil - top}+#{[left, 0].max}+#{[top, 0].max}"
      end
    end
  end
end
