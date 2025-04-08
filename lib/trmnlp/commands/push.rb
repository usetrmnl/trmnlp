require 'zip'

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Push < Base
      def call(plugin_settings_id)
        plugin_settings_id ||= config.plugin.id
        if plugin_settings_id.nil?
          puts 'The plugin ID must be specified on the first pull.'
          exit 1
        end

        unless options.force
          print "Plugin settings on the server will be overwritten. Are you sure? (y/n) "
          answer = $stdin.gets.chomp.downcase
          unless answer == 'y' || answer == 'yes'
            puts "Aborting"
            exit 1
          end
        end

        api = APIClient.new(config)
        size = 0

        Tempfile.create(binmode: true) do |temp_file|
          Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip_file|
            paths.src_files.each do |file|
              zip_file.add(File.basename(file), file)
            end
          end
        
          api.post_plugin_setting_archive(plugin_settings_id, temp_file.path)

          size = File.size(temp_file.path)
        end
        

        puts "Uploaded plugin (#{size} bytes)"
      end
    end
  end
end