# frozen_string_literal: true

module TRMNLP
  module TransformBackend
    # Code wrappers shared by Subprocess and Http backends. Each method
    # emits the canonical dispatch harness — read stdin → run user code
    # → find run/transform/result/passthrough → serialize output — and
    # delegates the final write to a language-appropriate `output_sink`
    # snippet supplied by the caller. Subprocess writes to a tempfile
    # path, Http writes to FD 3 for the production daemon to capture.
    #
    # Mirrors the hosted serverless runtime's code-wrapping behavior
    # verbatim except for the configurable sink.
    #
    # NOTE: `output_sink` is spliced verbatim into the generated script as
    # executable code. It MUST be trmnlp-generated (see Subprocess#sink_for
    # and Http#sink_for) and never derived from user input or config — an
    # attacker-influenced sink is arbitrary code execution in the transform
    # process. Only `code` is untrusted; the sink is part of the harness.
    module Wrapper
      module_function

      def python(code, output_sink)
        <<~PYTHON
          import sys, json, os
          input = json.loads(sys.stdin.read())

          #{code}

          if callable(locals().get('run', None)):
              output = run(input)
          elif 'result' in dir():
              output = result
          else:
              output = input
          #{output_sink}
        PYTHON
      end

      def ruby(code, output_sink)
        <<~RUBY
          require 'json'
          input = JSON.parse($stdin.read)

          #{code}

          output = if defined?(run) == 'method'
                     run(input)
                   elsif defined?(result)
                     result
                   else
                     input
                   end
          #{output_sink}
        RUBY
      end

      # NOTE: node also accepts `function transform(input)` for
      # production parity. Plugins authored against the hosted service
      # using `transform` would otherwise silently pass input through.
      def node(code, output_sink)
        <<~JS
          const input = JSON.parse(require('fs').readFileSync(0, 'utf8'));

          #{code}

          let output;
          if (typeof run === "function") {
            output = run(input);
          } else if (typeof transform === "function") {
            output = transform(input);
          } else if (typeof result !== "undefined") {
            output = result;
          } else {
            output = input;
          }
          #{output_sink}
        JS
      end

      # NOTE: strips a leading `<?php` tag from user code so plugin
      # authors can write the file as a standalone .php script. The
      # hosted service does the same.
      def php(code, output_sink)
        cleaned = code.sub(/\A\s*<\?php\s*/, '')
        <<~PHP
          <?php
          $input = json_decode(file_get_contents('php://stdin'), true);

          #{cleaned}

          if (function_exists('run')) {
              $output = run($input);
          } elseif (isset($result)) {
              $output = $result;
          } else {
              $output = $input;
          }
          #{output_sink}
        PHP
      end

      def for(language, code, output_sink)
        case language.to_s
        when 'python' then python(code, output_sink)
        when 'ruby'   then ruby(code, output_sink)
        when 'node'   then node(code, output_sink)
        when 'php'    then php(code, output_sink)
        end
      end
    end
  end
end
