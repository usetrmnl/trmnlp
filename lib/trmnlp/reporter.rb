# frozen_string_literal: true

require 'tone'

module TRMNLP
  # Single sink for user-facing command output. Records every message so
  # specs can assert on what a command would have said, and writes to the
  # underlying stream unless quiet:.
  class Reporter
    attr_reader :messages

    def initialize(quiet: false, stream: $stdout)
      @quiet = quiet
      @stream = stream
      @messages = []
      # Colour only when the stream is a real terminal, so ANSI codes
      # never leak into piped or redirected output.
      @tone = Tone.new(enabled: stream.tty?)
    end

    def info(message)
      @messages << message
      @stream.puts(message) unless @quiet
    end

    def green(text) = tone[text, :green]
    def yellow(text) = tone[text, :yellow]
    def red(text) = tone[text, :red]

    private

    attr_reader :tone
  end
end
