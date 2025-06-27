require 'zip'

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Push < Base
      def call
        context.validate!
        authenticate!

        is_new = false

        api = APIClient.new(config)

        plugin_settings_id = options.id || config.plugin.id
        if plugin_settings_id.nil?
          output 'Creating a new plugin on the server...'
          response = api.post_plugin_setting(name: 'New TRMNLP Plugin', plugin_id: 37) # hardcoded id for private_plugin
          plugin_settings_id = response.dig('data', 'id')
          is_new = true
        end

        unless is_new || options.force
          answer = prompt("Plugin settings on the server will be overwritten. Are you sure? (y/n) ").downcase
          raise Error, 'aborting' unless answer == 'y' || answer == 'yes'
        end

        size = 0

        zip_path = 'upload.zip'
        f = Zip::File.open(zip_path, Zip::File::CREATE) do |zip_file|
          paths.src_files.each do |file|
            zip_file.add(File.basename(file), file)
          end
        end
      
        response = api.post_plugin_setting_archive(plugin_settings_id, zip_path)
        paths.plugin_config.write(response.dig('data', 'settings_yaml'))

        size = File.size(zip_path)
        File.delete(zip_path)
        
        output <<~HEREDOC
        Uploaded plugin (#{size} bytes)
        Dashboard: #{config.app.edit_plugin_settings_uri(plugin_settings_id)}
        HEREDOC

        if is_new
          output <<~HEREDOC

          IMPORTANT! Don't forget to add it to your device playlist!

              #{config.app.playlists_uri}
          HEREDOC
        end
      end
    end
  end
end