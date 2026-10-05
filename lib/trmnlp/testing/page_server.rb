# frozen_string_literal: true

require 'securerandom'
require 'socket'

module TRMNLP
  module Testing
    # `trmnlp test --fast`: serves each rendered page from one local address, so Firefox opens it as a page
    # of its own. Written into about:blank, every page has its stylesheets parsed again, 1.5 seconds for
    # the Framework's; pages that share an address share the parsed copy, and a page's scripts wait for
    # its stylesheets as on any site.
    class PageServer
      ENV_KEY = 'TRMNLP_TEST_FAST'

      def initialize
        @pages = {}
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

      # The address html is served at until #forget.
      def add(html)
        id = SecureRandom.hex(8)
        @lock.synchronize { @pages[id] = html }
        "http://127.0.0.1:#{@server.addr[1]}/pages/#{id}"
      end

      def forget(url) = @lock.synchronize { @pages.delete(url.to_s.split('/').last) }

      private

      def serve(socket)
        path = socket.gets.to_s.split[1].to_s
        nil while (line = socket.gets) && !line.strip.empty?
        html = @lock.synchronize { @pages[path[%r{\A/pages/(\h+)\z}, 1]] }
        socket.write(html ? response('200 OK', html) : response('404 Not Found', ''))
      rescue IOError, SystemCallError
        nil
      ensure
        socket.close unless socket.closed?
      end

      def response(status, body)
        "HTTP/1.1 #{status}\r\ncontent-type: text/html; charset=utf-8\r\ncache-control: no-store\r\n" \
          "content-length: #{body.bytesize}\r\nconnection: close\r\n\r\n#{body}"
      end
    end
  end
end
