# frozen_string_literal: true

require_relative 'base'
require_relative 'init'
require_relative 'pull'

module TRMNLP
  module Commands
    class Clone < Base
      Options = Data.define(:dir, :quiet)

      def call(directory_name, id)
        authenticate!

        destination_path = Pathname.new(options.dir).join(directory_name)
        raise DirectoryExists, "directory #{destination_path} already exists, aborting" if destination_path.exist?

        Init.run({ dir: options.dir, skip_liquid: true, quiet: true }, directory_name)

        Pull.run({ dir: destination_path.to_s, force: true, id: id })

        reporter.info <<~HEREDOC

          To start the local server:

              cd #{Pathname.new(destination_path).relative_path_from(Dir.pwd)} && trmnlp serve
        HEREDOC
      end

      private

      def template_dir = paths.templates_dir.join('init')
    end
  end
end
