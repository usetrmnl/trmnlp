# frozen_string_literal: true

module TRMNLP
  module Lint
    # The plugin data every lint check examines: markup per view, shared
    # markup, the combined markup string, and the raw settings.yml. Built
    # once and shared across all checks. Settings come straight from
    # Config::Plugin (a single parse); checks read the raw `{{ }}` templates,
    # which Config::Plugin's semantic readers render away.
    class Source
      VIEWS = %w[full half_horizontal half_vertical quadrant].freeze

      def initialize(config:, paths:)
        @config = config
        @paths = paths
      end

      def plugin_name = settings['name'].to_s
      def settings = config.plugin.settings
      def custom_field_values = config.project.custom_fields
      def custom_field_definitions = config.plugin.custom_field_definitions

      def view_markup
        @view_markup ||= VIEWS.to_h { |view| [view, read(paths.template(view))] }
      end

      def shared_markup
        @shared_markup ||= read(paths.shared_template)
      end

      def all_markup
        @all_markup ||= view_markup.values.join + shared_markup
      end

      private

      attr_reader :config, :paths

      def read(path) = path.exist? ? path.read.strip : ''
    end
  end
end
