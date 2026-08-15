# frozen_string_literal: true

require 'fileutils'

require_relative 'base'

module TRMNLP
  module Commands
    class Init < Base
      Options = Data.define(:dir, :quiet, :skip_liquid, :skip_git)

      def call(name)
        destination_dir = Pathname.new(options.dir).join(name)

        unless destination_dir.exist?
          reporter.info "Creating #{destination_dir}"
          destination_dir.mkpath
        end

        # NOTE: FNM_DOTMATCH so the glob descends into hidden template
        # directories (e.g. .github/); without it those files are skipped.
        template_dir.glob('**/{*,.*}', File::FNM_DOTMATCH).each do |source_pathname|
          next if source_pathname.directory?
          next if options.skip_liquid && source_pathname.extname == '.liquid'

          relative_pathname = source_pathname.relative_path_from(template_dir)
          destination_pathname = destination_dir.join(relative_pathname)
          destination_pathname.dirname.mkpath

          if destination_pathname.exist?
            answer = prompt("#{destination_pathname} already exists. Overwrite? (y/n): ").downcase
            if answer != 'y'
              reporter.info "Skipping #{destination_pathname}"
              next
            end
          end

          reporter.info "Creating #{destination_pathname}"
          FileUtils.cp(source_pathname, destination_pathname)
          # NOTE: cp preserves the source mode. Templates installed read-only
          # (e.g. NixOS /nix/store is 0444) would leave the author unable to
          # edit their own project. Add owner-write; keep any exec bit.
          destination_pathname.chmod(destination_pathname.stat.mode | 0o200)
        end

        init_git_repo(destination_dir) unless options.skip_git

        reporter.info <<~HEREDOC

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

      # Make the scaffold a Git repository on `main` so it's ready to push
      # to GitHub (the workflow's `branches: [main]` trigger requires it,
      # regardless of the host's init.defaultBranch).
      # Does nothing when git is unavailable — `system` returns nil rather
      # than raising, so the scaffold itself still succeeds.
      def init_git_repo(dir) = system('git', 'init', '-q', '-b', 'main', dir.to_s)
    end
  end
end
