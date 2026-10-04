# frozen_string_literal: true

module TRMNLP
  module Testing
    # The peak memory of a running process, read every few milliseconds until it exits: VmHWM on Linux
    # (the kernel's own high-water mark), the resident size from ps on macOS (the highest one seen).
    class MemorySampler
      INTERVAL_SECONDS = 0.01

      def self.start(pid) = new(pid).tap(&:start)

      def initialize(pid)
        @pid = pid
        @peak_kb = nil
      end

      def start
        @thread = Thread.new do
          while (kb = read_kb)
            @peak_kb = [@peak_kb.to_i, kb].max
            sleep INTERVAL_SECONDS
          end
        end
      end

      def peak_mb
        @thread&.join
        @peak_kb && (@peak_kb / 1024.0).round(1)
      end

      private

      # nil once the process is gone.
      def read_kb
        return File.read("/proc/#{@pid}/status")[/VmHWM:\s+(\d+)/, 1]&.to_i if File.exist?('/proc/self/status')

        kb = IO.popen(['ps', '-o', 'rss=', '-p', @pid.to_s], err: File::NULL, &:read).strip
        kb.empty? ? nil : kb.to_i
      rescue SystemCallError
        nil
      end
    end
  end
end
