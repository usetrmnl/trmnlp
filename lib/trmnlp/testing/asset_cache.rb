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
      OVERRIDE_PATH = %r{\A/overrides/(\h{16})/(.*)\z}
      LOCAL = { 'cache_control' => 'no-store', 'allow_origin' => '*' }.freeze

      def initialize(dir:, clock: -> { Time.now })
        @dir = dir.to_s
        @clock = clock
        @overrides = {}
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
        rewritten = point_overrides_at(html, overrides:, base: "#{url}/overrides", swaps:, bundle_dir:)
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

      # A folder key keeps the rest of the URL, so files the asset links relative to itself resolve in the same folder.
      # The default base is the page's own server, so serve's preview reaches it from outside a container.
      def point_overrides_at(html, overrides:, base: '/overrides', swaps: nil, bundle_dir: nil)
        html.gsub(URL_LINK) do |source|
          key = overrides.keys.select { folder?(it) ? source.start_with?(it) : source == it }.max_by(&:length)
          next source unless key

          target = overrides.fetch(key)
          rest = folder?(key) ? source.delete_prefix(key) : File.basename(URI(source).path)
          check_local_file!(source, key, target, rest)
          swaps&.push(url: source, target: target.is_a?(Hash) ? '[inline body]' : resolve(key, target, rest),
                      kind: 'override')
          id = register_override(key, target)
          bundle_dir ? bundle_asset(id, key, target, rest, bundle_dir) : "#{base}/#{id}/#{rest}"
        end
      end

      def override_response(path, user_agent)
        asset = override_asset(path, user_agent) or return
        [200, { 'content-type' => asset['content_type'], 'cache-control' => asset['cache_control'],
                'access-control-allow-origin' => asset['allow_origin'] }.compact, [asset['body']]]
      end

      private

      def override_asset(path, user_agent)
        id, rest = path.match(OVERRIDE_PATH)&.captures
        key, target = @lock.synchronize { @overrides[id] }
        return unless key

        rest = URI.decode_uri_component(rest)
        return published_neighbor(key, rest, user_agent) unless folder?(key) || rest == File.basename(URI(key).path)

        overridden(key, target, rest, user_agent)
      end

      def folder?(key) = key.end_with?('/')

      def url?(target) = target.is_a?(String) && target.match?(%r{\Ahttps?://})

      def overridden(key, target, rest, user_agent)
        found = resolve(key, target, rest)
        type = mime(folder?(key) ? "#{key}#{rest}" : key)
        if found.is_a?(Hash)
          { 'body' => found.fetch(:body).to_s, 'content_type' => found[:content_type] || type }.merge(LOCAL)
        elsif url?(found) then remote_asset(found, user_agent)
        elsif found && File.file?(found) then { 'body' => File.binread(found), 'content_type' => type }.merge(LOCAL)
        end
      end

      # The file, URL or inline content an overridden URL stands for; nil for a path outside the folder.
      def resolve(key, target, rest)
        return target unless folder?(key)
        return "#{target}#{rest}" if url?(target)

        path = File.expand_path(rest.split('?', 2).first.to_s, target)
        path if path == File.expand_path(target) || path.start_with?("#{File.expand_path(target)}/")
      end

      def check_local_file!(source, key, target, rest)
        return if target.is_a?(Hash) || url?(target) || rest.empty?

        path = resolve(key, target, rest)
        raise InvalidConfig, "asset_overrides #{source}: no local file at #{path}" unless File.exist?(path.to_s)
      end

      # Keyed by what is swapped, so a page rewritten again gets the same address and the table stays one row per key.
      def register_override(key, target)
        Digest::SHA256.hexdigest("#{key} #{target.inspect}")[0, 16].tap { |id| @lock.synchronize { @overrides[id] = [key, target] } }
      end

      # A file next to an overridden single file comes from where it was published, on the same host.
      def published_neighbor(key, rest, user_agent)
        neighbor = URI.join(key, rest)
        remote_asset(neighbor.to_s, user_agent) if neighbor.host == URI(key).host
      end

      def bundle_asset(id, key, target, rest, dir)
        folder = File.join(dir, 'assets', id)
        if folder?(key) && !url?(target)
          FileUtils.mkdir_p(folder)
          FileUtils.cp_r("#{target}/.", folder)
        elsif !rest.empty? && !rest.end_with?('/')
          body = overridden(key, target, rest, nil)&.fetch('body')
          raise InvalidConfig, "asset_overrides #{key}: could not fetch #{resolve(key, target, rest)}" unless body

          FileUtils.mkdir_p(File.dirname(destination = File.join(folder, rest.split('?', 2).first)))
          File.binwrite(destination, body)
        end
        "assets/#{id}/#{rest}"
      end

      def remote_asset(target, user_agent)
        key = "/remote/#{Digest::SHA256.hexdigest(target)}"
        cached = cached(key)
        cached && cached['expires_at'] > @clock.call.to_i ? cached : download(key, URI(target), user_agent) || cached
      end

      def mime(source) = Rack::Mime.mime_type(File.extname(URI(source).path), 'application/octet-stream')

      def point_google_fonts_at_cache(text) = text.gsub(GOOGLE_FONTS_LINK) { "#{url}/#{::Regexp.last_match(1)}/" }

      def serve(socket)
        path, query = socket.gets.to_s.split[1].to_s.split('?', 2)
        user_agent = nil
        while (line = socket.gets) && !line.strip.empty?
          user_agent = line.split(':', 2).last.strip if line.downcase.start_with?('user-agent:')
        end
        asset = if path.to_s.start_with?('/overrides/') then override_asset(path, user_agent)
                elsif !path.to_s.include?('..') && path.to_s.match?(SAFE_PATH) then asset(path, query, user_agent)
                end
        socket.write(asset ? response(asset) : BAD_GATEWAY)
      rescue IOError, SystemCallError, URI::Error
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
