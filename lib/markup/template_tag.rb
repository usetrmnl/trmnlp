module Markup
  # The {% template [name] %} tag block is used in conjunction with InlineTemplatesFileSystem to allow users to define
  # custom templates within the context of the current Liquid template. Generally speaking, they will define their own
  # templates in the "shared" markup content, which is prepended to the individual screen templates before rendering.
  class TemplateTag < Liquid::Block
    NAME_REGEX = %r{\A[a-zA-Z0-9_/]+\z}

    def initialize(tag_name, markup, options)
      super
      @name = markup.strip
    end

    def parse(tokens)
      @body = ""
      while (token = tokens.shift)
        break if token.strip == "{% endtemplate %}"

        @body << token
      end
    end

    def render(context)
      unless @name =~ NAME_REGEX
        return "Liquid error: invalid template name #{@name.inspect} - template names must contain only letters, numbers, underscores, and slashes"
      end

      context.registers[:file_system].register(@name, @body.strip)
      ''
    end
  end
end