# frozen_string_literal: true

require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new { |task| task.verbose = false }
RuboCop::RakeTask.new

task default: :spec

namespace :framework do
  desc 'Sync db/data/framework_versions.yml from the published design-system manifest'
  task :sync, [:source_repo] do |_t, args|
    require 'open-uri'
    require_relative 'lib/trmnlp/framework_version'

    source_repo = args[:source_repo] || ENV.fetch('FRAMEWORK_SOURCE_REPO', nil)

    if source_repo
      source = File.expand_path(File.join(source_repo, 'db', 'data', 'framework_versions.yml'))
      abort "Source file not found: #{source}" unless File.exist?(source)
      contents = File.read(source)
    else
      source = TRMNLP::FrameworkVersion::MANIFEST_URL
      contents = URI.parse(source).read
    end

    destination = File.expand_path('db/data/framework_versions.yml', __dir__)
    header = <<~HEADER
      # Mirrored from the TRMNL design-system source.
      # Refresh with `rake framework:sync` — do not edit manually.
    HEADER

    # Strip the source's auto-generated banner if present, then prepend ours.
    body = contents.lines.reject { |l| l.start_with?('# This file is auto-generated') }.join
    File.write(destination, header + body)
    puts "Synced #{destination} from #{source}"
  end
end

namespace :i18n do
  desc "Sync db/data/and_x_more.yml from a trmnl-i18n checkout's plugin_renders locales"
  task :sync, [:source_repo] do |_t, args|
    require 'yaml'

    source_repo = args[:source_repo] || ENV.fetch('TRMNL_I18N_SOURCE_REPO') { abort 'Pass the trmnl-i18n path' }
    locales_dir = File.join(source_repo, 'lib', 'trmnl', 'i18n', 'locales', 'plugin_renders')
    phrases = Dir.glob(File.join(locales_dir, '*.yml')).filter_map do |file|
      locale, translations = YAML.load_file(file).first
      renders = translations&.dig('renders') || {}
      next unless renders['and_x_more_prefix']

      [locale, [renders['and_x_more_prefix'], renders['and_x_more_suffix']]]
    end

    destination = File.expand_path('db/data/and_x_more.yml', __dir__)
    header = <<~HEADER
      # Mirrored from trmnl-i18n (renders.and_x_more_prefix and _suffix), what TRMNL's
      # window.I18n.andXMore prints. Refresh with `rake i18n:sync[path]` — do not edit manually.
    HEADER
    File.write(destination, header + phrases.to_h.to_yaml.delete_prefix("---\n"))
    puts "Synced #{phrases.size} locales to #{destination} from #{locales_dir}"
  end
end
