# frozen_string_literal: true

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class List < Base
      Options = Data.define(:dir, :quiet)

      PRIVATE_PLUGIN_ID = 37

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
        reporter.info '  ID        NAME'
        reporter.info "  #{'-' * 50}"

        plugins.each do |plugin|
          reporter.info format('  %-8s  %s', plugin['id'], plugin['name'])
        end

        reporter.info "\nTo clone a plugin:"
        reporter.info '    trmnlp clone [folder_name] [id]'
      end
    end
  end
end
