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
    end

    def info(message)
      @messages << message
      @stream.puts(message) unless @quiet
    end

    def green(text) = colorize(text, 32)
    def yellow(text) = colorize(text, 33)

    private

    def colorize(text, code) = "\e[#{code}m#{text}\e[0m"
  end
end
