# frozen_string_literal: true

require 'digest'
require 'fileutils'
require 'json'
require 'net/http'
require 'rack/mime'
require 'socket'
require 'uri'

require_relative '../framework_version'
require_relative '../errors'

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
      URL_LINK = %r{https?://[^\s"'<>),;]+}

      def initialize(dir:, clock: -> { Time.now })
        @dir = dir.to_s
        @clock = clock
        @overrides = {}
        @next_override = 0
        @lock = Mutex.new
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

      def rewrite_if_configured(html, overrides:) = overrides.empty? ? html : rewrite(html, overrides:)

      # Rewrites text, including URL strings in scripts, before the normal Framework and font substitutions.
      def rewrite(html, overrides: {}, swaps: nil, bundle_dir: nil)
        rewritten = html.gsub(URL_LINK) do |source|
          key = overrides.keys.select do |candidate|
            candidate.end_with?('/') ? source.start_with?(candidate) : source == candidate
          end
                         .max_by(&:length)
          next source unless key

          target = overrides.fetch(key)
          resolved = target_for(source, key, target)
          swaps&.push(url: source, target: resolved.is_a?(Hash) ? '[inline body]' : resolved, kind: 'override')
          bundle_dir ? bundle_asset(source, resolved, bundle_dir) : register_override(source, resolved)
        end
        return rewritten if bundle_dir

        rewritten = rewritten.gsub(FRAMEWORK_LINK) do
          original = ::Regexp.last_match(0) + ::Regexp.last_match.post_match[/\A[^\s"'<>),;]*/].to_s
          swaps&.push(url: original, target: original.sub(HOST, url), kind: 'framework')
          url
        end
        rewritten.gsub(GOOGLE_FONTS_LINK) do
          host = ::Regexp.last_match(1)
          original = ::Regexp.last_match(0) + ::Regexp.last_match.post_match[/\A[^\s"'<>),;]*/].to_s
          swaps&.push(url: original, target: original.sub('https://', "#{url}/"), kind: 'fonts')
          "#{url}/#{host}/"
        end
      end

      private

      def target_for(source, key, target)
        unless key.end_with?('/')
          if target.is_a?(String) && !target.match?(%r{\Ahttps?://}) && !File.file?(target)
            raise InvalidConfig, "asset_overrides #{source}: local file does not exist: #{target}"
          end

          return target
        end

        suffix = source.delete_prefix(key)
        raise InvalidConfig, "asset_overrides #{source}: invalid path" if suffix.split('/').include?('..')

        if target.is_a?(String) && target.match?(%r{\Ahttps?://})
          "#{target}#{suffix}"
        else
          path = File.expand_path(suffix.split('?', 2).first, target.to_s)
          unless File.file?(path) && path.start_with?("#{File.expand_path(target.to_s)}/")
            raise InvalidConfig, "asset_overrides #{source}: local file does not exist: #{path}"
          end

          path
        end
      end

      def register_override(source, target)
        extension = File.extname(URI(source).path)
        extension = '.bin' if extension.empty?
        id = @lock.synchronize do
          @next_override += 1
          @overrides[@next_override.to_s] = [source, target]
          @next_override
        end
        "#{url}/overrides/#{id}/asset#{extension}"
      end

      def bundle_asset(source, target, dir)
        name = File.basename(URI(source).path)
        name = 'asset.bin' if name.empty?
        relative = "assets/#{Digest::SHA256.hexdigest(source)[0, 16]}/#{name}"
        body = if target.is_a?(Hash)
                 target.fetch(:body).to_s
               elsif target.match?(%r{\Ahttps?://})
                 remote_asset(target, nil)&.fetch('body')
               else
                 File.binread(target)
               end
        raise InvalidConfig, "asset_overrides #{source}: could not fetch #{target}" unless body

        destination = File.join(dir, relative)
        FileUtils.mkdir_p(File.dirname(destination))
        File.binwrite(destination, body)
        relative
      end

      def remote_asset(target, user_agent)
        key = "/remote/#{Digest::SHA256.hexdigest(target)}"
        cached = cached(key)
        cached && cached['expires_at'] > @clock.call.to_i ? cached : download(key, URI(target), user_agent) || cached
      end

      def override_asset(path, user_agent)
        id = path.split('/')[2]
        source, target = @lock.synchronize { @overrides[id] }
        return unless source

        if target.is_a?(Hash)
          { 'body' => target.fetch(:body).to_s, 'content_type' => target[:content_type] || mime(source),
            'cache_control' => 'no-store', 'allow_origin' => '*' }
        elsif target.match?(%r{\Ahttps?://})
          remote_asset(target, user_agent)
        else
          return unless File.file?(target)

          { 'body' => File.binread(target), 'content_type' => mime(source), 'cache_control' => 'no-store',
            'allow_origin' => '*' }
        end
      end

      def mime(source) = Rack::Mime.mime_type(File.extname(URI(source).path), 'application/octet-stream')

      def point_google_fonts_at_cache(text) = text.gsub(GOOGLE_FONTS_LINK) { "#{url}/#{::Regexp.last_match(1)}/" }

      def serve(socket)
        path, query = socket.gets.to_s.split[1].to_s.split('?', 2)
        user_agent = nil
        while (line = socket.gets) && !line.strip.empty?
          user_agent = line.split(':', 2).last.strip if line.downcase.start_with?('user-agent:')
        end
        asset = !path.to_s.include?('..') && path.to_s.match?(SAFE_PATH) &&
                (path.start_with?('/overrides/') ? override_asset(path, user_agent) : asset(path, query, user_agent))
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
        answer = Net::HTTP.start(uri.host, uri.port, use_ssl: uri.scheme == 'https', **timeouts) do |http|
          http.get(uri.request_uri, headers)
        end
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
