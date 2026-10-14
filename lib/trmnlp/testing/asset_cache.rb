# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'socket'

require_relative '../framework_version'

module TRMNLP
  module Testing
    # Serves the Framework's files and Google Fonts to test pages from disk, for as long as their hosts say.
    class AssetCache
      HOST = FrameworkVersion::DEFAULT_ASSET_HOST
      FRAMEWORK_LINK = %r{#{Regexp.escape(HOST)}(?=/(?:css|js)/)}
      GOOGLE_FONTS_LINK = %r{https://(fonts\.(?:googleapis|gstatic)\.com)/}
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

      def point_framework_links_at_cache(html) = point_google_fonts_at_cache(html.gsub(FRAMEWORK_LINK, url))

      private

      def point_google_fonts_at_cache(text) = text.gsub(GOOGLE_FONTS_LINK) { "#{url}/#{::Regexp.last_match(1)}/" }

      def serve(socket)
        path, query = socket.gets.to_s.split[1].to_s.split('?', 2)
        user_agent = nil
        while (line = socket.gets) && !line.strip.empty?
          user_agent = line.split(':', 2).last.strip if line.downcase.start_with?('user-agent:')
        end
        asset = !path.to_s.include?('..') && path.to_s.match?(SAFE_PATH) && asset(path, query, user_agent)
        socket.write(asset ? response(asset) : BAD_GATEWAY)
      rescue IOError, SystemCallError
        nil
      ensure
        socket.close unless socket.closed?
      end

      def asset(path, query, user_agent)
        key = query ? "#{path}.#{Digest::SHA256.hexdigest(query)[0, 16]}" : path
        cached = cached(key)
        return cached if cached && cached['expires_at'] > @clock.call.to_i

        download(key, URI("#{upstream(path)}#{"?#{query}" if query}"), user_agent) || cached
      end

      # A Google Fonts path starts with its host, /fonts.gstatic.com/s/...; any other path is trmnl.com's.
      def upstream(path)
        host, rest = path.delete_prefix('/').split('/', 2)
        host.match?(/\Afonts\.(googleapis|gstatic)\.com\z/) ? "https://#{host}/#{rest}" : "#{HOST}#{path}"
      end

      def cached(key)
        meta = JSON.parse(File.read(file(key, '.json')))
        meta.merge('body' => File.binread(file(key)))
      rescue Errno::ENOENT, JSON::ParserError
        nil
      end

      # trmnl.com sends its CORS header only to a request with an Origin; Google picks the font format by User-Agent.
      def download(key, uri, user_agent)
        headers = { 'Origin' => url, 'User-Agent' => user_agent }.compact
        timeouts = { open_timeout: DOWNLOAD_TIMEOUT_SECONDS, read_timeout: DOWNLOAD_TIMEOUT_SECONDS }
        answer = Net::HTTP.start(uri.host, uri.port, use_ssl: true, **timeouts) { it.get(uri.request_uri, headers) }
        answer.is_a?(Net::HTTPSuccess) ? cache_download(key, answer) : nil
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

      # A stylesheet's Google font files are pointed at the cache as it is served, since the cache's port changes.
      def response(asset)
        stylesheet = asset['content_type'].to_s.start_with?('text/css')
        body = stylesheet ? point_google_fonts_at_cache(asset['body']) : asset['body']
        headers = { 'content-type' => asset['content_type'], 'cache-control' => asset['cache_control'],
                    'access-control-allow-origin' => asset['allow_origin'],
                    'content-length' => body.bytesize, 'connection' => 'close' }.compact
        "HTTP/1.1 200 OK\r\n#{headers.map { "#{it[0]}: #{it[1]}\r\n" }.join}\r\n#{body}"
      end
    end
  end
end
