# frozen_string_literal: true

require 'fileutils'
require 'tmpdir'
require 'zip'

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Push < Base
      Options = Data.define(:dir, :quiet, :id, :force)

      # Build the archive under the system temp dir, not the working
      # directory — a relative path would litter the user's project (or the
      # repo root, in specs) if a run is interrupted before the ensure-cleanup.
      ZIP_PATH = File.join(Dir.tmpdir, "trmnlp-upload-#{Process.pid}.zip").freeze

      def call
        context.validate!
        authenticate!

        is_new = false

        api = APIClient.new(config)

        plugin_settings_id = options.id || config.plugin.id
        if plugin_settings_id.nil?
          reporter.info 'Creating a new plugin on the server...'
          response = api.post_plugin_setting(name: 'New TRMNLP Plugin', plugin_id: 37) # hardcoded id for private_plugin
          plugin_settings_id = response.dig('data', 'id')
          is_new = true
        end

        unless is_new || options.force
          answer = prompt('Plugin settings on the server will be overwritten. Are you sure? (y/n) ').downcase
          raise Aborted, 'aborting' unless %w[y yes].include?(answer)
        end

        Zip::File.open(ZIP_PATH, create: true) do |zip_file|
          paths.src_files.each do |file|
            zip_file.add(File.basename(file), file)
          end
        end

        response = api.post_plugin_setting_archive(plugin_settings_id, ZIP_PATH)
        paths.plugin_config.write(response.dig('data', 'settings_yaml'))

        size = File.size(ZIP_PATH)

        reporter.info <<~HEREDOC
          Uploaded plugin (#{size} bytes)
          Dashboard: #{config.app.edit_plugin_settings_uri(plugin_settings_id)}
        HEREDOC

        if is_new
          reporter.info <<~HEREDOC

            IMPORTANT! Don't forget to add it to your device playlist!

                #{config.app.playlists_uri}
          HEREDOC
        end
      rescue StandardError
        if is_new && plugin_settings_id
          reporter.info 'Error during creation, cleaning up...'
          api.delete_plugin_setting(plugin_settings_id)
        end

        raise
      ensure
        FileUtils.rm_f(ZIP_PATH)
      end
    end
  end
end
