# frozen_string_literal: true

require 'rbconfig'

require_relative '../errors'

module TRMNLP
  module Testing
    # Starts every clock a run reads at the test's time: Ruby's own (Liquid's `now`, the trmnl namespace)
    # and, through libfaketime, the transform process's, whatever its language.
    module FrozenClock
      LIBRARY_ENV_KEY = 'TRMNLP_LIBFAKETIME'
      LIBRARY_GLOBS = {
        darwin: %w[/opt/homebrew/opt/libfaketime/lib/faketime/libfaketime.1.dylib
                   /usr/local/opt/libfaketime/lib/faketime/libfaketime.1.dylib],
        linux: %w[/usr/lib/*/faketime/libfaketime.so.1 /usr/lib/faketime/libfaketime.so.1
                  /usr/local/lib/faketime/libfaketime.so.1]
      }.freeze
      INSTALL_HINTS = { darwin: 'brew install libfaketime', linux: 'apt-get install libfaketime' }.freeze
      # macOS drops DYLD_* variables for the binaries System Integrity Protection guards.
      PROTECTED_PREFIXES = %w[/usr/bin/ /bin/ /sbin/ /usr/sbin/ /System/].freeze

      # Answers Time.now with the frozen time on the current thread while it is set.
      module FrozenNow
        def now(...) = Thread.current[:trmnlp_frozen_now]&.dup || super
      end
      Time.singleton_class.prepend(FrozenNow)

      module_function

      def around(time)
        previous = Thread.current[:trmnlp_frozen_now]
        Thread.current[:trmnlp_frozen_now] = time
        yield
      ensure
        Thread.current[:trmnlp_frozen_now] = previous
      end

      # The clock reads its time from clock_file on every call, so #move can set it forward mid-run.
      def environment(time, interpreter:, clock_file:)
        os = operating_system
        library = library_path(os)
        refuse_protected(interpreter) if os == :darwin

        write(clock_file, time)
        preload_variables(os, library).merge('FAKETIME_TIMESTAMP_FILE' => clock_file.to_s, 'FAKETIME_NO_CACHE' => '1',
                                             'FAKETIME_DONT_FAKE_MONOTONIC' => '1', 'FAKETIME_DONT_RESET' => '1',
                                             'TZ' => 'UTC')
      end

      def write(clock_file, time) = File.write(clock_file, "#{time.utc.strftime('@%Y-%m-%d %H:%M:%S')}\n")

      def preload_variables(os, library)
        return { 'LD_PRELOAD' => library } if os == :linux

        { 'DYLD_INSERT_LIBRARIES' => library, 'DYLD_FORCE_FLAT_NAMESPACE' => '1' }
      end

      def operating_system
        case RbConfig::CONFIG['host_os']
        when /darwin/ then :darwin
        when /linux/ then :linux
        else raise TestingError, 'A frozen clock needs libfaketime, which runs on macOS and Linux only'
        end
      end

      def library_path(os)
        return ENV[LIBRARY_ENV_KEY] if ENV[LIBRARY_ENV_KEY]

        found = LIBRARY_GLOBS.fetch(os).flat_map { Dir.glob(it) }.first
        return found if found

        raise TestingError,
              "A frozen clock needs libfaketime: #{INSTALL_HINTS.fetch(os)} (or set #{LIBRARY_ENV_KEY})"
      end

      def refuse_protected(interpreter)
        real_path = File.realpath(interpreter)
        return unless PROTECTED_PREFIXES.any? { real_path.start_with?(it) }

        raise TestingError,
              "macOS will not freeze the clock for #{real_path}; install the interpreter with brew or mise"
      end
    end
  end
end
