# frozen_string_literal: true

require 'xdg'

module TRMNLP
  module TransformBackend
    # TRMNL's serverless Python has requests installed. A Python without it runs transforms from a
    # virtual environment in the cache that has it, made once; if that fails, the Python runs as it is.
    module Python
      module_function

      def interpreter(python, venv_dir: XDG.new.cache_home.join('trmnl', 'python'))
        resolved[python] ||= imports_requests?(python) ? python : venv_python(python, venv_dir)
      end

      def venv_python(python, venv_dir)
        venv_dir.dirname.mkpath
        venv = venv_dir.join(Gem.win_platform? ? 'Scripts/python.exe' : 'bin/python').to_s
        created = File.open("#{venv_dir}.lock", File::RDWR | File::CREAT) do |lock|
          lock.flock(File::LOCK_EX)
          imports_requests?(venv) || created_venv?(python, venv_dir, venv)
        end
        created ? venv : python
      end

      def created_venv?(python, venv_dir, venv)
        succeeds?(python, '-m', 'venv', '--clear', venv_dir.to_s) && succeeds?(venv, '-m', 'pip', 'install', 'requests')
      end

      def imports_requests?(python) = succeeds?(python, '-c', 'import requests')

      def succeeds?(*command) = system(*command, out: File::NULL, err: File::NULL) == true

      def resolved = @resolved ||= {}
    end
  end
end
