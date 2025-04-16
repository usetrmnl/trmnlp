require 'fileutils'

require_relative 'base'

module TRMNLP
  module Commands
    class Init < Base
      def call(name)
        destination_dir = Pathname.new(options.dir).join(name)

        unless destination_dir.exist?
          output "Creating #{destination_dir}"
          destination_dir.mkpath
        end

        template_dir.glob('**/{*,.*}').each do |source_pathname|
          next if source_pathname.directory?
          next if options.skip_liquid && source_pathname.extname == '.liquid'

          relative_pathname = source_pathname.relative_path_from(template_dir)
          destination_pathname = destination_dir.join(relative_pathname)
          destination_pathname.dirname.mkpath
          
          if destination_pathname.exist?
            answer = prompt("#{destination_pathname} already exists. Overwrite? (y/n): ").downcase
            if answer != 'y'
              output "Skipping #{destination_pathname}"
              next
            end
          end

          output "Creating #{destination_pathname}"
          FileUtils.cp(source_pathname, destination_pathname)
        end

        output <<~HEREDOC

        To start the local server:

            cd #{Pathname.new(destination_dir).relative_path_from(Dir.pwd)}
            trmnlp serve

        To publish the plugin:

            trmnlp login
            trmnlp push
        HEREDOC
      end

      private

      def template_dir = paths.templates_dir.join('init')  
    end
  end
end