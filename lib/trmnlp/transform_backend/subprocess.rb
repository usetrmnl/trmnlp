# frozen_string_literal: true

require 'open3'
require 'tmpdir'

require_relative '../transform_client'
require_relative 'which'
require_relative 'wrapper'

module TRMNLP
  module TransformBackend
    # Local subprocess execution of user transform code. Mirrors the
    # remote-daemon wrapper contract so a transform behaves the same
    # locally as it does in production. Output flows back via
    # a tempfile per-execution instead of FD 3, but the
    # run/result/input dispatch logic is preserved verbatim via the
    # shared Wrapper module.
    class Subprocess
      DEFAULT_TIMEOUT = 30
      # Seconds a TERM'd process is given to exit before escalating to KILL.
      GRACE_PERIOD = 0.1

      # Candidate commands per language, highest priority first. Windows is
      # why a language needs more than one: its python.org installer provides
      # `python` and the `py` launcher but no `python3`. `py` ranks last yet
      # is the surest Windows hit — it stays on PATH even when the installer's
      # optional "Add to PATH" step is skipped.
      INTERPRETERS = {
        'python' => { cmds: %w[python3 python py], ext: 'py' },
        'ruby' => { cmds: %w[ruby],                ext: 'rb' },
        'node' => { cmds: %w[node],                ext: 'js' },
        'php' => { cmds: %w[php],                  ext: 'php' }
      }.freeze

      def execute(code:, language:, stdin: '', timeout_seconds: DEFAULT_TIMEOUT)
        spec = INTERPRETERS[language.to_s]
        return failure("unsupported language: #{language}") unless spec

        invoke(spec, language.to_s, code, stdin, timeout_seconds)
      end

      private

      def invoke(spec, language, code, stdin, timeout_seconds)
        Dir.mktmpdir('trmnlp-tx-') do |dir|
          output_path = File.join(dir, 'output.json')
          src_path = File.join(dir, "transform.#{spec[:ext]}")
          File.write(src_path, Wrapper.for(language, code, sink_for(language, output_path)))
          run_process(Which.resolve(spec[:cmds]), src_path, stdin, timeout_seconds, output_path)
        end
      rescue Errno::ENOENT, Errno::EACCES => e
        failure("interpreter not available: #{e.message}")
      end

      def run_process(cmd, src_path, stdin, timeout_seconds, output_path)
        started = monotonic_ms

        Open3.popen3(cmd, src_path) do |stdin_io, stdout_io, stderr_io, wait_thr|
          stdin_io.write(stdin)
          stdin_io.close

          unless wait_thr.join(timeout_seconds)
            kill(wait_thr)
            return failure("timeout after #{timeout_seconds}s", monotonic_ms - started)
          end

          build_result(stdout_io.read, stderr_io.read, wait_thr.value, output_path, monotonic_ms - started)
        end
      end

      def build_result(stdout, stderr, status, output_path, duration_ms)
        TransformClient::Result.new(
          stdout: stdout,
          stderr: stderr,
          output: read_output(output_path),
          exit_code: status.exitstatus || -1,
          duration_ms: duration_ms,
          error: nil
        )
      end

      # A transform that crashes before writing leaves no output file; a
      # permissions/IO error on read is treated the same — empty output,
      # which the pipeline surfaces as a non-JSON-output failure.
      def read_output(path)
        File.exist?(path) ? File.read(path) : ''
      rescue SystemCallError
        ''
      end

      # TERM first, escalating to KILL only if the process outlives the
      # grace period. join returns the moment it exits, so a process that
      # dies promptly on TERM costs near-zero wait, not a fixed sleep.
      def kill(wait_thr)
        Process.kill('TERM', wait_thr.pid)
        return if wait_thr.join(GRACE_PERIOD)

        Process.kill('KILL', wait_thr.pid)
      rescue Errno::ESRCH
        # already exited between TERM and KILL — fine
      end

      def failure(message, duration_ms = 0)
        TransformClient::Result.new(
          stdout: '', stderr: '', output: '',
          exit_code: -1, duration_ms: duration_ms, error: message
        )
      end

      def monotonic_ms = (Process.clock_gettime(Process::CLOCK_MONOTONIC) * 1000).to_i

      # Language-specific tempfile sink snippets. The dispatch harness
      # in Wrapper.* writes `output` (a serializable value); these
      # snippets get it onto disk so the parent process can read it.
      def sink_for(language, output_path)
        case language
        when 'python'
          # A single statement — no block indentation to keep in sync with
          # the Wrapper.python heredoc. open() is flushed and closed when
          # CPython drops the temporary as the process exits.
          "json.dump(output, open(#{output_path.inspect}, 'w'))"
        when 'ruby'
          "File.write(#{output_path.inspect}, JSON.generate(output))"
        when 'node'
          <<~JS.chomp
            Promise.resolve(output)
              .then((o) => require('fs').writeFileSync(#{output_path.inspect}, JSON.stringify(o)))
              .catch((err) => { process.stderr.write(err.stack || String(err)); process.exit(1); });
          JS
        when 'php'
          "file_put_contents(#{output_path.inspect}, json_encode($output));"
        end
      end
    end
  end
end
