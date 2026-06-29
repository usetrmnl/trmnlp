# frozen_string_literal: true

module TRMNLP
  module TransformBackend
    # Resolves a command to the interpreter actually present on PATH, so one
    # transform runs unchanged on platforms that name an interpreter
    # differently — most pressingly Windows, which ships no `python3`.
    module Which
      module_function

      # Falls back to the first candidate when none resolve, leaving the
      # caller to surface the usual "interpreter not available" ENOENT.
      def resolve(candidates, path: ENV.fetch('PATH', ''), pathext: ENV.fetch('PATHEXT', ''))
        candidates.find { |cmd| locate(cmd, path: path, pathext: pathext) } || candidates.first
      end

      # Windows marks executables by extension, enumerated in PATHEXT
      # (.EXE/.BAT/...); POSIX leaves PATHEXT unset and relies on the exec bit.
      def locate(cmd, path: ENV.fetch('PATH', ''), pathext: ENV.fetch('PATHEXT', ''))
        suffixes = pathext.split(File::PATH_SEPARATOR)
        suffixes = [''] if suffixes.empty?
        path.split(File::PATH_SEPARATOR)
            .product(suffixes)
            .map { |dir, suffix| File.join(dir, "#{cmd}#{suffix}") }
            .find { |candidate| File.file?(candidate) && File.executable?(candidate) }
      end
    end
  end
end
