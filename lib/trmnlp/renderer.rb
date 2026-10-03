# frozen_string_literal: true

require 'erb'
require 'json'
require 'yaml'
require 'trmnl/liquid'

require_relative 'screen'

module TRMNLP
  class Renderer
    # TRMNL refuses to render merge variables past this size.
    MAX_MERGE_VARIABLES_BYTES = 100 * 1024
    AND_X_MORE = YAML.load_file(File.expand_path('../../db/data/and_x_more.yml', __dir__)).freeze

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

    def screen_classes(classes = 'screen', theme: nil)
      classes = (classes || 'screen').split # an explicit nil (omitted screen_classes param) still needs a base
      # The picker marks every render 1x, which sets the dither ratio; TRMNL's device render has no such class.
      classes.delete('screen--1x')
      classes << 'screen--no-bleed' if config.plugin.no_screen_padding == 'yes'
      classes << 'screen--dark-mode' if config.plugin.dark_mode == 'yes'
      # Framework 1.x inverts only on the bare dark-mode class.
      classes << 'dark-mode' if classes.include?('screen--dark-mode')
      # A new device renders in the TRMNL font unless its owner picks another.
      classes << 'screen--fonts-trmnl' if classes.none? { it.start_with?('screen--fonts-') }
      classes << "screen--theme-#{theme}" if FrameworkVersion::THEMES.key?(theme)
      classes.uniq.join(' ')
    end

    # TRMNL's window.I18n.andXMore phrase for the user's locale, as [prefix, suffix].
    def and_x_more
      locale = config.project.user_data_overrides.dig('trmnl', 'user', 'locale').to_s
      AND_X_MORE[locale] || AND_X_MORE[locale.split('-').first] || AND_X_MORE['en']
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
      data = user_data_assembler.call(device:)
      size = JSON.generate(data.except('trmnl')).bytesize
      if size > MAX_MERGE_VARIABLES_BYTES
        raise RenderError, "Large payload received (#{size} bytes), should be less than 100kb."
      end

      Liquid::Template.parse(full_markup(template_path), environment: liquid_environment).render(data)
    rescue RenderError
      raise
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

    # ivars must match the @-references in web/views/render_html.erb
    class TemplateBinding
      def initialize(renderer, view, params)
        @view = view
        @screen_classes = renderer.screen_classes(params[:screen_classes], theme: params[:theme])
        @framework = renderer.framework
        @theme_css_url = @framework.theme_css_url(params[:theme])
        @and_x_more = renderer.and_x_more
        @mashup_classes = Screen.find(view)&.mashup_classes
      end

      def get_binding = binding
    end
  end
end
