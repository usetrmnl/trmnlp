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
          puts 'Creating a new plugin on the server...'
          response = api.post_plugin_setting(name: 'New TRMNLP Plugin', plugin_id: 37) # hardcoded id for private_plugin
          plugin_settings_id = response.dig('data', 'id')
          is_new = true
        end

        unless is_new || options.force
          print "Plugin settings on the server will be overwritten. Are you sure? (y/n) "
          answer = $stdin.gets.chomp.downcase
          raise Error, 'aborting' unless answer == 'y' || answer == 'yes'
        end

        size = 0

        Tempfile.create(binmode: true) do |temp_file|
          Zip::File.open(temp_file.path, Zip::File::CREATE) do |zip_file|
            paths.src_files.each do |file|
              zip_file.add(File.basename(file), file)
            end
          end
        
          response = api.post_plugin_setting_archive(plugin_settings_id, temp_file.path)
          paths.plugin_config.write(response.dig('data', 'settings_yaml'))

          size = File.size(temp_file.path)
        end
        
        puts <<~HEREDOC
        Uploaded plugin (#{size} bytes)
        Dashboard: #{config.app.edit_plugin_settings_uri(plugin_settings_id)}
        HEREDOC

        if is_new
          puts <<~HEREDOC

          IMPORTANT! Don't forget to add it to your device playlist!

              #{config.app.playlists_uri}
          HEREDOC
        end
      end
    end
  end
end