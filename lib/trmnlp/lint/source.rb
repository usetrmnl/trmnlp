# frozen_string_literal: true

require 'nokogiri'
require 'trmnl/liquid'
require 'yaml'

module TRMNLP
  module Lint
    # The plugin data every lint check examines: markup per view, shared
    # markup, the combined markup string, and the raw settings.yml. Built
    # once and shared across all checks. Settings come straight from
    # Config::Plugin (a single parse); checks read the raw `{{ }}` templates,
    # which Config::Plugin's semantic readers render away.
    class Source
      VIEWS = %w[full half_horizontal half_vertical quadrant].freeze
      LIQUID_COMMENT = /\{%-?\s*comment\s*-?%\}.*?\{%-?\s*endcomment\s*-?%\}/m

      def initialize(config:, paths:)
        @config = config
        @paths = paths
      end

      def plugin_name = settings['name'].to_s
      def plugin_description = settings['description'].to_s
      def recipe_overview = settings['recipe_overview'].to_s
      def framework_version = config.plugin.framework_version
      def settings = config.plugin.settings
      def custom_field_values = config.project.custom_fields
      def custom_field_definitions = config.plugin.custom_field_definitions

      def local_only_filter_names
        config.project.user_filter_modules.flat_map(&:public_instance_methods).map(&:to_s).uniq -
          TRMNL::Liquid.new.filter_method_names
      end

      def view_markup
        @view_markup ||= VIEWS.to_h { |view| [view, read(paths.template(view))] }
      end

      def shared_markup
        @shared_markup ||= read(paths.shared_template)
      end

      def all_markup
        @all_markup ||= view_markup.values.join + shared_markup
      end

      # The serverless transform (src/transform.{py,rb,php,js}), or '' without one.
      # It reads custom fields from its input, so a field may be used only there.
      def transform_code
        @transform_code ||= begin
          path, = paths.transform_file
          path ? read(path) : ''
        end
      end

      # Keep the original whitespace here: stripped templates cannot provide
      # accurate line/column numbers. All paths in reports are project-relative.
      def markup_files
        @markup_files ||= (VIEWS + ['shared']).to_h do |view|
          ["src/#{view}.liquid", raw_read(paths.template(view))]
        end
      end

      # Parsed without render data: Liquid output becomes `{{}}` and tags become spaces,
      # so the classes of every branch count and a quote inside Liquid cannot end an attribute.
      # Each replacement keeps the newlines it replaced, so element lines stay true.
      def html_fragments
        @html_fragments ||= markup_files.transform_values do |markup|
          html = markup.gsub(LIQUID_COMMENT) { "\n" * it.count("\n") }
                       .gsub(/\{\{.*?\}\}/m) { "{{}}#{"\n" * it.count("\n")}" }
                       .gsub(/\{%.*?%\}/m) { " #{"\n" * it.count("\n")}" }
          Nokogiri::HTML.fragment(html)
        end
      end

      def element_location(path, element)
        snippet = markup_files.fetch(path).lines[element.line - 1].to_s.chomp
        { path:, line: element.line, column: (snippet.index(/<#{element.name}\b/i) || 0) + 1, snippet: snippet[0, 240] }
      end

      def locations(pattern, files: markup_files)
        files.flat_map do |path, contents|
          contents.to_enum(:scan, pattern).map do
            offset = Regexp.last_match.begin(0)
            prefix = contents[0...offset]
            line = prefix.count("\n") + 1
            { path:, line:, column: offset - (prefix.rindex("\n") || -1),
              snippet: contents.lines[line - 1].to_s.chomp[0, 240] }
          end
        end.uniq
      end

      def yaml_location(file, *keys)
        path = file == '.trmnlp.yml' ? paths.trmnlp_config : paths.plugin_config
        contents = raw_read(path)
        node = Psych.parse_stream(contents).children.first&.root
        keys.each do |key|
          node = if key.is_a?(Integer) && node.is_a?(Psych::Nodes::Sequence)
                   node.children[key]
                 else
                   mapping_value(node, key)
                 end
        end
        return [] unless node

        [{ path: file, line: node.start_line + 1, column: node.start_column + 1,
           snippet: contents.lines[node.start_line].to_s.chomp[0, 240] }]
      end

      private

      attr_reader :config, :paths

      def raw_read(path) = path.exist? ? path.read : ''

      def mapping_value(node, key)
        return unless node.is_a?(Psych::Nodes::Mapping)

        node.children.each_slice(2).to_a.rfind { |name, _| name.value == key.to_s }&.last
      end

      def read(path) = path.exist? ? path.read.strip : ''
    end
  end
end
