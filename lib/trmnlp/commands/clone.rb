require_relative 'base'
require_relative 'pull'

module TRMNLP
  module Commands
    class Clone < Base
      def call(directory_name, id)
        authenticate!

        destination_path = Pathname.new(options.dir).join(directory_name)
        raise Error, "directory #{destination_path} already exists, aborting" if destination_path.exist?

        Init.new(dir: options.dir, skip_liquid: true, quiet: true).call(directory_name)

        Pull.new(dir: destination_path.to_s, force: true, id: id).call

        puts <<~HEREDOC

        To start the local server:

            cd #{Pathname.new(destination_path).relative_path_from(Dir.pwd)} && trmnlp serve
        HEREDOC
      end

      private

      def template_dir = paths.templates_dir.join('init')
    end
  end
end