# frozen_string_literal: true

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class List < Base
      Options = Data.define(:dir, :quiet)

      PRIVATE_PLUGIN_ID = 37
      ID_WIDTH = 8
      RULE_WIDTH = 50

      def call
        authenticate!

        api = APIClient.new(config)
        response = api.get_plugin_settings
        plugins = (response || [])
                  .select { |p| p['plugin_id'].nil? || p['plugin_id'] == PRIVATE_PLUGIN_ID }
                  .sort_by { |p| (p['name'] || '').downcase }

        if plugins.empty?
          reporter.info 'No plugins found.'
          return
        end

        reporter.info "Your plugins:\n\n"
        report_table(plugins)

        reporter.info "\nTo clone a plugin:"
        reporter.info '    trmnlp clone [folder_name] [id]'
      end

      private

      def report_table(plugins)
        return report_names(plugins) if plugins.none? { |plugin| description(plugin) }

        report_names_and_descriptions(plugins)
      end

      def report_names(plugins)
        ids = id_width(plugins)
        report_header format("%-#{ids}s  %s", 'ID', 'NAME')

        plugins.each do |plugin|
          reporter.info format("  %-#{ids}s  %s", plugin['id'], plugin['name'])
        end
      end

      def report_names_and_descriptions(plugins)
        ids = id_width(plugins)
        names = column_width(plugins.map { |plugin| plugin['name'] }, 'NAME'.length)
        report_header format("%-#{ids}s  %-#{names}s  %s", 'ID', 'NAME', 'DESCRIPTION')

        plugins.each do |plugin|
          row = format("  %-#{ids}s  %-#{names}s  %s", plugin['id'], plugin['name'], description(plugin))
          reporter.info row.rstrip
        end
      end

      # BYOS servers return a UUID for plugins created there and the original
      # number for plugins imported from the hosted service, so one response
      # can hold both widths.
      def id_width(plugins) = column_width(plugins.map { |plugin| plugin['id'] }, ID_WIDTH)

      def column_width(values, minimum) = [*values.map { |value| value.to_s.length }, minimum].max

      def report_header(text)
        reporter.info "  #{text}"
        reporter.info "  #{'-' * [text.length, RULE_WIDTH].max}"
      end

      def description(plugin)
        value = plugin['description'].to_s.strip
        value unless value.empty?
      end
    end
  end
end
