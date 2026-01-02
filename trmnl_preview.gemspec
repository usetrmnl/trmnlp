# frozen_string_literal: true

require_relative "lib/trmnlp/version"

Gem::Specification.new do |spec|
  spec.name = "trmnl_preview"
  spec.version = TRMNLP::VERSION
  spec.authors = ["Rockwell Schrock"]
  spec.email = ["rockwell@schrock.me"]

  spec.summary = "Local web server to preview TRMNL plugins"
  spec.description = "Automatically rebuild and preview TRNML plugins in multiple views"
  spec.homepage = "https://github.com/usetrmnl/trmnlp"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/usetrmnl/trmnlp"

  spec.files = Dir.chdir(__dir__) do
    [
      'bin/**/*',
      'lib/**/*',
      'templates/**/{*,.*}',
      'web/**/*',
      'CHANGELOG.md',
      'LICENSE.txt',
      'README.md',
      'trmnl_preview.gemspec'
    ].flat_map { |glob| Dir[glob] }
  end
  spec.bindir = "bin"
  spec.executables = ["trmnlp"]
  spec.require_paths = ["lib"]


  # Web server
  spec.add_dependency "sinatra", "~> 4.1"
  spec.add_dependency "rackup", "~> 2.2"
  spec.add_dependency "puma", "~> 6.5"
  spec.add_dependency "faye-websocket", "~> 0.11.3"

  # HTML rendering
  spec.add_dependency "activesupport", "~> 8.0"
  spec.add_dependency "trmnl-liquid", "~> 0.2.0"

  # PNG rendering
  spec.add_dependency 'puppeteer-bidi', '~> 0.0.3'
  spec.add_dependency 'mini_magick', '~> 4.12.0'

  # Utilities
  spec.add_dependency "filewatcher", "~> 2.1"
  spec.add_dependency "faraday", "~> 2.1"
  spec.add_dependency "faraday-multipart", "~> 1.1"
  spec.add_dependency "xdg", "~> 9.1"
  spec.add_dependency "rubyzip", "~> 2.3.0"
  spec.add_dependency "thor", "~> 1.3"
  spec.add_dependency "oj", "~> 3.16.9"
  spec.add_dependency "tzinfo-data", "~> 1.2025"
  spec.add_dependency "pathname", "~> 0.4"
  spec.add_dependency "rexml", "~> 3.4"

  # For more information and examples about making a new gem, check out our
  # guide at: https://bundler.io/guides/creating_gem.html
end
