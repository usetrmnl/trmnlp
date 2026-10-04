# frozen_string_literal: true

require 'openssl'
require 'socket'

module TRMNLP
  module Testing
    # The HTTP(S) proxy a transform process runs behind, answering from a MockTable. HTTPS is opened with
    # certificates from CertificateAuthority, so mocks work for every language and library that honors
    # the proxy variables. One request per connection, then the connection closes.
    class MockProxy
      def initialize(table:, authority:)
        @table = table
        @authority = authority
      end

      def self.open(table:, authority:)
        proxy = new(table:, authority:).start
        yield proxy
      ensure
        proxy&.stop
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

      def environment
        proxy = "http://127.0.0.1:#{@server.addr[1]}"
        { 'HTTP_PROXY' => proxy, 'HTTPS_PROXY' => proxy, 'http_proxy' => proxy, 'https_proxy' => proxy,
          'NO_PROXY' => '', 'no_proxy' => '', 'NODE_USE_ENV_PROXY' => '1' }.merge(@authority.environment)
      end

      private

      def serve(socket)
        verb, target = socket.gets.to_s.split
        return socket.close unless verb

        verb == 'CONNECT' ? serve_tunnel(socket, target) : serve_request(socket, verb, target, read_headers(socket))
      rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
        nil
      ensure
        socket.close unless socket.closed?
      end

      def serve_tunnel(socket, target)
        read_headers(socket)
        host, port = target.split(':')
        socket.write("HTTP/1.1 200 Connection Established\r\n\r\n")
        tls = OpenSSL::SSL::SSLSocket.new(socket, @authority.ssl_context_for(host))
        tls.accept
        verb, path = tls.gets.to_s.split
        origin = port == '443' ? "https://#{host}" : "https://#{host}:#{port}"
        serve_request(tls, verb, origin + path.to_s, read_headers(tls))
        tls.close
      end

      def serve_request(io, verb, url, headers)
        body = read_body(io, headers)
        response = @table.answer(verb, url, headers:, body:, via: :transform)
        return io.close unless response
        return if hung_up?(io)

        write_response(io, response)
        response.record[:delivered] = true
      rescue IOError, SystemCallError, OpenSSL::SSL::SSLError
        nil
      end

      def write_response(io, response)
        body = response.body.b
        io.write(head(response, body.bytesize))
        io.flush
        sleep(response.body_delay) if response.body_delay
        io.write(body)
      end

      # A transform that gave up (its own timeout, an abort signal) has closed the connection by now.
      def hung_up?(io)
        socket = io.respond_to?(:to_io) ? io.to_io : io
        return false unless socket.wait_readable(0)

        socket.recv_nonblock(1, Socket::MSG_PEEK, exception: false).then { it.nil? || it.empty? }
      end

      def read_headers(io)
        headers = {}
        while (line = io.gets) && !line.strip.empty?
          name, value = line.split(':', 2)
          headers[name.strip.downcase] = value.to_s.strip
        end
        headers
      end

      def read_body(io, headers)
        return io.read(headers['content-length'].to_i) if headers['content-length']
        return nil unless headers['transfer-encoding'].to_s.include?('chunked')

        chunks = +''
        while (size = io.gets.to_s.to_i(16)).positive?
          chunks << io.read(size)
          io.gets
        end
        io.gets
        chunks
      end

      def head(response, length)
        lines = response.headers.reject { |name, _| %w[content-length connection].include?(name.downcase) }
                        .map { |name, value| "#{name}: #{value}" }
        "HTTP/1.1 #{response.status} Mocked\r\n#{lines.join("\r\n")}\r\ncontent-length: #{length}\r\n" \
          "connection: close\r\n\r\n"
      end
    end
  end
end
