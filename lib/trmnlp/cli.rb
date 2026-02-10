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
    def build
      Commands::Build.new(options).call
    end

    desc 'login', 'Authenticate with TRMNL server'
    def login
      Commands::Login.new(options).call
    end

    desc 'init NAME', 'Start a new plugin project'
    method_option :skip_liquid, type: :boolean, default: false, desc: 'Skip generating liquid templates'
    def init(name)
      Commands::Init.new(options).call(name)
    end

    desc 'clone NAME ID', 'Copy a plugin project from TRMNL server'
    def clone(name, id)
      Commands::Clone.new(options).call(name, id)
    end

    desc 'list', 'List private plugins from TRMNL server'
    def list
      Commands::List.new(options).call
    end

    desc 'pull', 'Download latest plugin settings from TRMNL server'
    method_option :force, type: :boolean, default: false, aliases: '-f',
                  desc: 'Skip confirmation prompts'
    method_option :id, type: :string, aliases: '-i', desc: 'Plugin settings ID'
    def pull
      Commands::Pull.new(options).call
    end

    desc 'push', 'Upload latest plugin settings to TRMNL server'
    method_option :force, type: :boolean, default: false, aliases: '-f',
                  desc: 'Skip confirmation prompts'
    method_option :id, type: :string, aliases: '-i', desc: 'Plugin settings ID'
    def push
      Commands::Push.new(options).call
    end

    desc 'lint', 'Validate plugin code against TRMNL best practices'
    def lint
      Commands::Lint.new(options).call
    end

    desc 'serve', 'Start a local dev server'
    method_option :bind, type: :string, default: default_bind, aliases: '-b', desc: 'Bind address'
    method_option :port, type: :numeric, default: 4567, aliases: '-p', desc: 'Port number'
    def serve
      Commands::Serve.new(options).call
    end

    desc 'version', 'Show version'
    def version
      puts VERSION
    end
  end
end