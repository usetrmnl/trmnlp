require 'zip'

require_relative 'base'
require_relative '../api_client'
require_relative '../context'

module TRMNLP
  module Commands
    class Pull < Base
      def call(plugin_settings_id)
        context = Context.new(options.dir)
        plugin_settings_id ||= context.config.plugin.id
        if plugin_settings_id.nil?
          puts 'The plugin ID must be specified on the first pull.'
          exit 1
        end

        api = APIClient.new(context.config)
        temp_path = api.get_plugin_setting_archive(plugin_settings_id)
        size = 0

        begin
          Zip::File.open(temp_path) do |zip_file|
            zip_file.each do |entry|
              dest_path = context.paths.src_dir.join(entry.name)
              dest_path.dirname.mkpath
              zip_file.extract(entry, dest_path) { true } # overwrite existing
            end
          end

          size = File.size(temp_path)
        ensure
          temp_path.delete
        end

        puts "Downloaded plugin (#{size} bytes)"
      end
    end
  end
end