require 'zip'

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Pull < Base
      def call(plugin_settings_id)
        plugin_settings_id ||= config.plugin.id
        if plugin_settings_id.nil?
          puts 'The plugin ID must be specified.'
          exit 1
        end

        unless options.force
          print "Local plugin files will be overwritten. Are you sure? (y/n) "
          answer = $stdin.gets.chomp.downcase
          unless answer == 'y' || answer == 'yes'
            puts "Aborting"
            exit 1
          end
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