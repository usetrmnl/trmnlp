# frozen_string_literal: true

require 'fileutils'
require 'json'
require 'net/http'
require 'socket'

require_relative '../framework_version'

module TRMNLP
  module Testing
    # Serves trmnl.com's Framework files to test pages from disk, for as long as trmnl.com says to keep them.
    class AssetCache
      HOST = FrameworkVersion::DEFAULT_ASSET_HOST
      FRAMEWORK_LINK = %r{#{Regexp.escape(HOST)}(?=/(?:css|js)/)}
      SAFE_PATH = %r{\A/(?:[\w.-]+/)*[\w.-]+\z}
      DOWNLOAD_TIMEOUT_SECONDS = 10
      BAD_GATEWAY = "HTTP/1.1 502 Bad Gateway\r\ncontent-length: 0\r\nconnection: close\r\n\r\n"

      def initialize(dir:, clock: -> { Time.now })
        @dir = dir.to_s
        @clock = clock
      end

      def start
        @server = TCPServer.new('127.0.0.1', 0)
        @thread = Thread.new { loop { Thread.new(@server.accept) { serve(it) } } }
        self
      end

      def stop
        @thread&.kill
        @server&.close
      end

      def url = "http://127.0.0.1:#{@server.addr[1]}"

      def point_framework_links_at_cache(html) = html.gsub(FRAMEWORK_LINK, url)

      private

      def serve(socket)
        path = socket.gets.to_s.split[1].to_s.split('?').first.to_s
        nil while (line = socket.gets) && !line.strip.empty?
        asset = !path.include?('..') && path.match?(SAFE_PATH) && asset(path)
        socket.write(asset ? response(asset) : BAD_GATEWAY)
      rescue IOError, SystemCallError
        nil
      ensure
        socket.close unless socket.closed?
      end

      def asset(path)
        cached = cached(path)
        return cached if cached && cached['expires_at'] > @clock.call.to_i

        download(path) || cached
      end

      def cached(path)
        meta = JSON.parse(File.read(file(path, '.json')))
        meta.merge('body' => File.binread(file(path)))
      rescue Errno::ENOENT, JSON::ParserError
        nil
      end

      def download(path)
        uri = URI("#{HOST}#{path}")
        timeouts = { open_timeout: DOWNLOAD_TIMEOUT_SECONDS, read_timeout: DOWNLOAD_TIMEOUT_SECONDS }
        answer = Net::HTTP.start(uri.host, uri.port, use_ssl: true, **timeouts) { it.get(uri.path, 'Origin' => url) }
        answer.is_a?(Net::HTTPSuccess) ? cache_download(path, answer) : nil
      rescue StandardError
        nil
      end

      def cache_download(path, answer)
        meta = { 'content_type' => answer['content-type'], 'cache_control' => answer['cache-control'],
                 'allow_origin' => answer['access-control-allow-origin'],
                 'expires_at' => @clock.call.to_i + answer['cache-control'].to_s[/max-age=(\d+)/, 1].to_i }
        write_to_disk(path, answer.body, meta)
        meta.merge('body' => answer.body)
      end

      def write_to_disk(path, body, meta)
        write(file(path), body)
        write(file(path, '.json'), JSON.generate(meta))
      rescue SystemCallError
        nil
      end

      # Written beside the file and renamed over it, so another run reading the cache sees a whole file.
      def write(path, content)
        FileUtils.mkdir_p(File.dirname(path))
        temporary = "#{path}.#{Process.pid}.#{Thread.current.object_id}"
        File.binwrite(temporary, content)
        File.rename(temporary, path)
      end

      def file(path, extension = '') = File.join(@dir, "#{path}#{extension}")

      def response(asset)
        headers = { 'content-type' => asset['content_type'], 'cache-control' => asset['cache_control'],
                    'access-control-allow-origin' => asset['allow_origin'],
                    'content-length' => asset['body'].bytesize, 'connection' => 'close' }.compact
        "HTTP/1.1 200 OK\r\n#{headers.map { "#{it[0]}: #{it[1]}\r\n" }.join}\r\n#{asset['body']}"
      end
    end
  end
end
