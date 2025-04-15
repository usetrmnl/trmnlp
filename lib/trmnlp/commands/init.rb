require 'fileutils'

require_relative 'base'

module TRMNLP
  module Commands
    class Init < Base
      def call(name)
        destination_dir = Pathname.new(Dir.pwd).join(name)

        unless destination_dir.exist?
          puts "Creating #{destination_dir}"
          destination_dir.mkpath
        end

        template_dir.glob('**/{*,.*}').each do |source_pathname|
          next if source_pathname.directory?

          relative_pathname = source_pathname.relative_path_from(template_dir)
          destination_pathname = destination_dir.join(relative_pathname)
          destination_pathname.dirname.mkpath
          
          if destination_pathname.exist?
            print "#{destination_pathname} already exists. Overwrite? (y/n): "
            answer = $stdin.gets.chomp.downcase
            if answer != 'y'
              puts "Skipping #{destination_pathname}"
              next
            end
          end

          puts "Creating #{destination_pathname}"
          FileUtils.cp(source_pathname, destination_pathname)
        end

        # TODO: print out next steps: cd #{name}, trmnlp serve, trmnlp push, etc
      end

      private

      def template_dir = paths.templates_dir.join('init')  
    end
  end
end