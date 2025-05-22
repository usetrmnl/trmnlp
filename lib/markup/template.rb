# get all files in the current directory as this file
Pathname.new(__dir__).glob('*.rb').each { |file| require file }

module Markup
  # A very thin wrapper around Liquid::Template with TRMNL-specific functionality.
  class Template < Liquid::Template
    def self.parse(*)
      template = super

      # set up a temporary in-memory file system for custom user templates, via the magic :file_system register
      # which will override the default file system
      template.registers[:file_system] = InlineTemplatesFileSystem.new

      template
    end
  end
end
