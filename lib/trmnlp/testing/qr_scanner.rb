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
        xml, error, status = Open3.capture3(COMMAND, '--quiet', '--xml', '-Sdisable', '-Sqrcode.enable', path)
        # zbarimg exits 4 when the picture has no code.
        raise TestingError, "zbarimg could not scan #{path}: #{error.strip}" unless [0, 4].include?(status.exitstatus)

        Nokogiri::XML(xml).remove_namespaces!.xpath('//symbol/data').map(&:text)
      rescue Errno::ENOENT
        raise TestingError, MISSING
      end

      def cropped
        return [] unless (geometry = crop_geometry)

        Tempfile.create(['trmnlp-qr-', '.png']) do |file|
          MiniMagick::Image.open(@path).crop(geometry).write(file.path)
          yield file.path
        end
      end

      def crop_geometry
        left = [@area.left.floor, 0].max
        top = [@area.top.floor, 0].max
        width = @area.right.ceil - left
        height = @area.bottom.ceil - top
        # ImageMagick reads a 0 width or height as the whole picture, so an area off it has nothing to crop.
        "#{width}x#{height}+#{left}+#{top}" if width.positive? && height.positive?
      end
    end
  end
end
