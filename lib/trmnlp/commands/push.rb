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

        removal_requested = !is_new && confirm_server_transform_removal?(api, plugin_settings_id)
        build_archive(removal_requested)

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

      private

      def build_archive(removal_requested)
        Zip::File.open(ZIP_PATH, create: true) do |zip_file|
          paths.src_files.each do |file|
            next if removal_requested && file == paths.plugin_config

            zip_file.add(File.basename(file), file)
          end
          if removal_requested
            zip_file.get_output_stream('settings.yml') { |entry| entry.write(settings_yaml_with_removal_request) }
          end
        end
      end

      # Without this, deleting a local transform.* is a silent no-op: the server
      # keeps executing its copy and every pull re-creates the file. The pushed
      # settings.yml carries `serverless_language: none`, which the importer
      # consumes as an explicit removal request.
      def confirm_server_transform_removal?(api, plugin_settings_id)
        return false if options.force
        return false if paths.transform_file.first
        return false unless server_transform?(api, plugin_settings_id)

        question = 'The server has a transform script, but this project has no transform file. ' \
                   'Delete it on the server too? (y/N) '
        %w[y yes].include?(prompt(question).downcase)
      end

      def server_transform?(api, plugin_settings_id)
        archive = api.get_plugin_setting_archive(plugin_settings_id)
        begin
          Zip::File.open(archive.path) { |zip_file| zip_file.any? { |entry| entry.name.start_with?('transform.') } }
        ensure
          archive.close
        end
      rescue Error
        # Advisory check only — an unreadable archive must not block the push.
        false
      end

      def settings_yaml_with_removal_request
        config.plugin.settings.merge('serverless_language' => 'none').to_yaml
      end
    end
  end
end
