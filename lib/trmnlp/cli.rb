require 'thor'

require_relative '../trmnlp'
require_relative '../trmnlp/commands'

module TRMNLP
  class CLI < Thor
    package_name 'trmnlp'

    class_option :dir, type: :string, default: Dir.pwd, aliases: '-d',
                  desc: 'Plugin directory'

    def self.exit_on_failure? = true

    desc 'build', 'Generate static HTML files'
    def build
      Commands::Build.new(options).call
    end

    desc 'login', 'Authenticate with TRMNL server'
    def login
      Commands::Login.new(options).call
    end

    desc 'pull [id]', 'Download plugin settings from TRMNL server'
    method_option :force, type: :boolean, default: false, aliases: '-f',
                  desc: 'Skip confirmation prompts'
    def pull(plugin_settings_id = nil)
      Commands::Pull.new(options).call(plugin_settings_id)
    end

    desc 'push [id]', 'Upload plugin settings to TRMNL server'
    method_option :force, type: :boolean, default: false, aliases: '-f',
                  desc: 'Skip confirmation prompts'
    def push(plugin_settings_id = nil)
      Commands::Push.new(options).call(plugin_settings_id)
    end

    desc 'serve', 'Start a local dev server'
    method_option :bind, type: :string, default: '127.0.0.1', aliases: '-b', desc: 'Bind address'
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