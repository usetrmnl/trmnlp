require 'net/http'
require 'uri'

require_relative 'base'

module TRMNLP
  module Commands
    class Lint < Base
      MAX_TITLE_LENGTH = 50
      MAX_INLINE_STYLES = 6

      MARKUP_VIEWS = %w[full half_horizontal half_vertical quadrant].freeze

      INLINE_STYLE_PROPERTIES = %w[
        justify-content padding margin background-color
        border-radius text-align object-fit font-size
      ].freeze

      def call
        context.validate!

        @suggestions = []

        run_checks

        if @suggestions.empty?
          output "\e[32m✓ All checks passed!\e[0m"
        else
          output "\e[33m#{@suggestions.size} issue#{'s' if @suggestions.size > 1} found:\e[0m\n\n"
          @suggestions.each_with_index do |suggestion, i|
            output "  #{i + 1}. #{suggestion[:message]}"
            output "     Learn more: #{suggestion[:learn_more]}" if suggestion[:learn_more]
          end
          output ""
        end

        @suggestions.empty?
      end

      private

      def run_checks
        checks.each do |method_name, suggestion_data|
          result = send(method_name)
          next if result == true

          if result.is_a?(Array)
            result.each { |s| suggest(s) }
          else
            suggest(suggestion_data)
          end
        end
      end

      def suggest(data)
        @suggestions << data
        @suggestions.uniq!
      end

      def checks
        {
          title_casing: {
            message: 'Title should begin with a capital letter.'
          },
          title_length: {
            message: "Title should be <= #{MAX_TITLE_LENGTH} characters long."
          },
          markups_have_content: {
            message: 'Some markup layouts are empty, please provide basic treatment.'
          },
          async_functions_are_not_present: {
            message: 'Async JavaScript functions are not allowed due to browser timeout settings for generating screenshots.'
          },
          waits_for_dom_load: {
            message: 'JavaScript should listen for the DOMContentLoaded event, not window.onLoad()',
            learn_more: 'https://help.trmnl.com/en/articles/9510536-private-plugins#h_db7030f8b8'
          },
          inline_styles_are_not_present: {
            message: 'Markup uses too many inline styles, add more native Framework classes.',
            learn_more: 'https://help.trmnl.com/en/articles/11395668-recipe-best-practices#h_3a3eab0712'
          },
          markup_size_elements_are_excluded: {
            message: "We already apply the 'full', 'half_horizontal', 'half_vertical', and 'quadrant' classes to each view, please remove them."
          },
          highcharts_animations_are_disabled: {
            message: 'Highcharts should have animations disabled.',
            learn_more: 'https://trmnl.com/framework/chart'
          },
          highcharts_elements_are_unique: {
            message: 'To avoid variable shadowing across charts in multiple layouts, use the append_random filter for your Highcharts elements.',
            learn_more: 'https://help.trmnl.com/en/articles/10347358-custom-plugin-filters'
          },
          image_links_respond_ok: {
            message: 'One or more <img> tags has a static "src" URL that does not respond to HTTP GET requests with a success code.'
          },
          custom_fields_values_are_used: nil # returns its own suggestions array
        }
      end

      # --- Plugin name from settings.yml ---

      def plugin_name
        @plugin_name ||= plugin_settings['name'] || ''
      end

      def plugin_settings
        @plugin_settings ||= if paths.plugin_config.exist?
                                YAML.load_file(paths.plugin_config)
                              else
                                {}
                              end
      end

      # --- Markup helpers ---

      def markup_contents
        @markup_contents ||= MARKUP_VIEWS.map do |view|
          template_path = paths.template(view)
          content = template_path.exist? ? template_path.read.strip : ''
          { view => content }
        end
      end

      def shared_markup
        @shared_markup ||= begin
          path = paths.shared_template
          path.exist? ? path.read.strip : ''
        end
      end

      def all_markup_string
        @all_markup_string ||= (markup_contents.map(&:values).join + shared_markup)
      end

      # --- Checks ---

      def title_casing
        return true if plugin_name.empty?

        plugin_name[0] == plugin_name[0].upcase
      end

      def title_length
        return true if plugin_name.empty?

        plugin_name.length <= MAX_TITLE_LENGTH
      end

      def markups_have_content
        markup_contents.each do |markup_content|
          markup = markup_content.values.first
          return false unless [markup.length, shared_markup.length].max >= 10
        end

        true
      end

      def async_functions_are_not_present
        !all_markup_string.downcase.include?('async function')
      end

      def waits_for_dom_load
        lower = all_markup_string.downcase
        return false if lower.include?('window.onload')
        return false if lower.include?('window.addeventlistener("load")')
        return false if lower.include?("window.addeventlistener('load')")

        true
      end

      def inline_styles_are_not_present
        count = INLINE_STYLE_PROPERTIES.sum { |prop| all_markup_string.scan(prop).size }

        count <= MAX_INLINE_STYLES
      end

      def markup_size_elements_are_excluded
        pattern = /\b(view(--|__)(full|half_horizontal|half_vertical|quadrant))\b("|')>/
        !all_markup_string.match?(pattern)
      end

      def highcharts_animations_are_disabled
        return true unless all_markup_string.downcase.include?('highcharts')

        all_markup_string.match?(/animation:\s{0,6}false/)
      end

      def highcharts_elements_are_unique
        return true unless all_markup_string.downcase.include?('highcharts')

        all_markup_string.match?(/append_random/)
      end

      def image_links_respond_ok
        markup_contents.each do |markup_content|
          html = markup_content.values.first
          # Simple regex to extract src attributes from <img> tags
          html.scan(/<img[^>]+src\s*=\s*["']([^"']+)["']/i).flatten.each do |src|
            src = src.strip
            next if src.include?('{{') # skip dynamic/interpolated URLs
            next if src.start_with?('data:') # skip data URIs

            return false if src.empty? || !src.match?(%r{\Ahttps?://})

            begin
              uri = URI.parse(src)
              response = Net::HTTP.get_response(uri)
              return false unless response.is_a?(Net::HTTPSuccess) || response.is_a?(Net::HTTPRedirection)
            rescue StandardError
              return false
            end
          end
        end

        true
      end

      def custom_fields_values_are_used
        fields = config.project.custom_fields
        return true if fields.empty?

        suggestions = []
        searchable_settings = [
          plugin_settings['polling_url'],
          plugin_settings['polling_headers'],
          plugin_settings['polling_body']
        ].compact.join(' ')

        fields.each_key do |keyname|
          pattern = /#{Regexp.escape(keyname)}/
          used = searchable_settings.match?(pattern) || all_markup_string.match?(pattern)
          suggestions << { message: "Custom field '#{keyname}' is not used in form fields or markup." } unless used
        end

        suggestions.empty? ? true : suggestions
      end
    end
  end
end
