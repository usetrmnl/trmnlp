require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class List < Base
      def call
        authenticate!

        api = APIClient.new(config)
        response = api.get_plugin_settings
        plugins = (response['data'] || [])
          .select { |p| p['plugin_id'] == 37 }
          .sort_by { |p| (p['name'] || '').downcase }

        if plugins.empty?
          output "No plugins found."
          return
        end

        output "Your plugins:\n\n"
        output "  %-8s  %s" % ["ID", "NAME"]
        output "  " + "-" * 50

        plugins.each do |plugin|
          output "  %-8s  %s" % [plugin['id'], plugin['name']]
        end

        output "\nTo clone a plugin:"
        output "    trmnlp clone [folder_name] [id]"
      end
    end
  end
end
