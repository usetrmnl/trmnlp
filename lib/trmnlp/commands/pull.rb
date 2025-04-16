require 'zip'

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Pull < Base
      def call
        context.validate!
        authenticate!

        plugin_settings_id = options.id || config.plugin.id
        raise Error, 'plugin ID must be specified' if plugin_settings_id.nil?

        unless options.force
          answer = prompt("Local plugin files will be overwritten. Are you sure? (y/n) ").downcase
          raise Error, 'aborting' unless answer == 'y' || answer == 'yes'
        end

        api = APIClient.new(config)
        temp_path = api.get_plugin_setting_archive(plugin_settings_id)
        size = 0

        begin
          Zip::File.open(temp_path) do |zip_file|
            zip_file.each do |entry|
              dest_path = paths.src_dir.join(entry.name)
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