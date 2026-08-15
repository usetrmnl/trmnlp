# frozen_string_literal: true

require 'zip'

require_relative 'base'
require_relative '../api_client'

module TRMNLP
  module Commands
    class Pull < Base
      Options = Data.define(:dir, :quiet, :id, :force)

      def call
        context.validate!
        authenticate!

        plugin_settings_id = options.id || config.plugin.id
        raise PluginIdRequired, 'plugin ID must be specified' if plugin_settings_id.nil?

        unless options.force
          answer = prompt('Local plugin files will be overwritten. Are you sure? (y/n) ').downcase
          raise Aborted, 'aborting' unless %w[y yes].include?(answer)
        end

        api = APIClient.new(config)
        tempfile = api.get_plugin_setting_archive(plugin_settings_id)
        size = 0

        begin
          Zip::File.open(tempfile.path) do |zip_file|
            zip_file.each do |entry|
              dest_path = paths.src_dir.join(entry.name)
              dest_path.dirname.mkpath
              # NOTE: delete-before-extract avoids EACCES on Linux when an
              # existing template-generated file is non-writable.
              # rubyzip's block-based overwrite confirmation does not chmod.
              dest_path.delete if dest_path.exist?
              zip_file.extract(entry, destination_directory: paths.src_dir)
            end
          end

          size = File.size(tempfile.path)
        ensure
          tempfile.close
        end

        reporter.info "Downloaded plugin (#{size} bytes)"
      end
    end
  end
end
