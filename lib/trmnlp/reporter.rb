# frozen_string_literal: true

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
      @tty = stream.tty?
    end

    def info(message)
      @messages << message
      @stream.puts(message) unless @quiet
    end

    def green(text) = colorize(text, 32)
    def yellow(text) = colorize(text, 33)
    def red(text) = colorize(text, 31)

    private

    def colorize(text, code) = @tty ? "\e[#{code}m#{text}\e[0m" : text
  end
end
