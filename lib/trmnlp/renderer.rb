# frozen_string_literal: true

require 'erb'
require 'trmnl/liquid'

require_relative 'screen'

module TRMNLP
  class Renderer
    def initialize(config:, paths:, user_data_assembler:)
      @config = config
      @paths = paths
      @user_data_assembler = user_data_assembler
    end

    def render_full_page(view, params = {})
      device = user_data_assembler.device_from_params(params)
      binding_obj = TemplateBinding.new(self, view, params)
      ERB.new(paths.render_template.read).result(
        binding_obj.get_binding { render_or_error(view, device:) }
      )
    end

    def framework = config.plugin.framework_version

    def screen_classes(classes = 'screen')
      classes ||= 'screen' # an explicit nil (omitted screen_classes param) still needs a base
      classes += ' screen--no-bleed' if config.plugin.no_screen_padding == 'yes'
      classes
    end

    private

    attr_reader :config, :paths, :user_data_assembler

    # NOTE: a missing template or Liquid syntax error is a user-facing
    # signal — the plugin author needs to *see* what broke. We surface
    # those as RenderError, then #render_or_error embeds the message
    # inside the preview frame so the dev server keeps serving instead
    # of 500-ing. Anything that's not a RenderError bubbles up as a bug.
    def render_liquid_template(view, device: {})
      template_path = paths.template(view)
      raise RenderError, "Missing template: #{template_path}" unless template_path.exist?

      parse_and_render(template_path, device:)
    end

    def parse_and_render(template_path, device:)
      Liquid::Template.parse(full_markup(template_path), environment: liquid_environment)
                      .render(user_data_assembler.call(device:))
    rescue StandardError => e
      raise RenderError, e.message
    end

    def render_or_error(view, device:)
      render_liquid_template(view, device:)
    rescue RenderError => e
      e.message
    end

    def full_markup(template_path)
      shared = paths.shared_template
      shared.exist? ? shared.read + template_path.read : template_path.read
    end

    def liquid_environment
      @liquid_environment ||= TRMNL::Liquid.new do |env|
        config.project.user_filters.each do |module_name, relative_path|
          require paths.root_dir.join(relative_path)
          env.register_filter(Object.const_get(module_name))
        end
      end
    end

    # bindings must match the `GET /render/{view}.html` route in app.rb
    class TemplateBinding
      def initialize(renderer, view, params)
        @view = view
        @screen_classes = renderer.screen_classes(params[:screen_classes])
        @framework = renderer.framework
        @mashup_classes = Screen.find(view)&.mashup_classes
      end

      def get_binding = binding
    end
  end
end
