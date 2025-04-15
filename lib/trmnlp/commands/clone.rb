require_relative 'base'
require_relative 'pull'

require 'thor/core_ext/hash_with_indifferent_access'

module TRMNLP
  module Commands
    class Clone < Base
      include Thor::CoreExt

      def call(directory_name, id)
        authenticate!

        destination_path = Pathname.new(options.dir).join(directory_name)
        raise Error, "directory #{destination_path} already exists, aborting" if destination_path.exist?

        puts "Creating #{destination_path}"
        destination_path.mkpath

        FileUtils.cp(template_dir.join('.trmnlp.yml'), destination_path.join('.trmnlp.yml'))

        pull_options = HashWithIndifferentAccess.new(
          dir: destination_path.to_s,
          force: true,
          id: id,
        )
        pull = Pull.new(pull_options)
        pull.call

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