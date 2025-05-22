module Markup
  # This in-memory "file system" is the backing storage for custom templates defined {% template [name] %} tags.
  class InlineTemplatesFileSystem < Liquid::BlankFileSystem
    def initialize
      super
      @templates = {}
    end

    # called by Markup::LiquidTemplateTag to save users' custom shared templates via our custom {% template %} tag
    def register(name, body)
      @templates[name] = body
    end

    # called by Liquid::Template for {% render 'foo' %} when rendering screen markup
    def read_template_file(name)
      @templates[name] || raise(Liquid::FileSystemError, "Template not found: #{name}")
    end
  end
end
