# frozen_string_literal: true

require 'thor'

require_relative '../trmnlp'
require_relative '../trmnlp/commands'

module TRMNLP
  class CLI < Thor
    package_name 'trmnlp'

    class_option :dir, type: :string, default: Dir.pwd, aliases: '-d',
                       desc: 'Plugin project directory'

    class_option :quiet, type: :boolean, default: false, desc: 'Suppress output', aliases: '-q'

    def self.exit_on_failure? = true

    def self.default_bind = File.exist?('/.dockerenv') ? '0.0.0.0' : '127.0.0.1'

    desc 'build', 'Generate static HTML files'
    method_option :png, type: :boolean, default: false, desc: 'Also render a PNG per view'
    method_option :width, type: :numeric, desc: 'PNG width in pixels (with --png)'
    method_option :height, type: :numeric, desc: 'PNG height in pixels (with --png)'
    method_option :color_depth, type: :numeric, desc: 'PNG bit depth: 1-8 (with --png)'
    def build
      Commands::Build.run(options)
    end

    desc 'login', 'Authenticate with TRMNL server'
    def login
      Commands::Login.run(options)
    end

    desc 'init NAME', 'Start a new plugin project'
    method_option :skip_liquid, type: :boolean, default: false, desc: 'Skip generating liquid templates'
    def init(name)
      Commands::Init.run(options, name)
    end

    desc 'clone NAME ID', 'Copy a plugin project from TRMNL server'
    def clone(name, id)
      Commands::Clone.run(options, name, id)
    end

    desc 'list', 'List private plugins from TRMNL server'
    def list
      Commands::List.run(options)
    end

    desc 'pull', 'Download latest plugin settings from TRMNL server'
    method_option :force, type: :boolean, default: false, aliases: '-f',
                          desc: 'Skip confirmation prompts'
    method_option :id, type: :string, aliases: '-i', desc: 'Plugin settings ID'
    def pull
      Commands::Pull.run(options)
    end

    desc 'push', 'Upload latest plugin settings to TRMNL server'
    method_option :force, type: :boolean, default: false, aliases: '-f',
                          desc: 'Skip confirmation prompts'
    method_option :id, type: :string, aliases: '-i', desc: 'Plugin settings ID'
    def push
      Commands::Push.run(options)
    end

    desc 'lint', 'Check plugin code against TRMNL best practices'
    def lint
      # Exit non-zero when issues are found so CI pipelines can gate on it.
      exit(1) unless Commands::Lint.run(options)
    end

    desc 'serve', 'Start a local dev server'
    method_option :bind, type: :string, default: default_bind, aliases: '-b', desc: 'Bind address'
    method_option :port, type: :numeric, default: 4567, aliases: '-p', desc: 'Port number'
    def serve
      Commands::Serve.run(options)
    end

    desc 'version', 'Show version'
    def version
      puts VERSION
    end
  end
end
