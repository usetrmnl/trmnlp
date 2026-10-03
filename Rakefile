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

# TRMNL's config.i18n.available_locales; trmnlp offers one locale per file in db/data/locales.
TRMNL_AVAILABLE_LOCALES = %w[en zh-CN cs da de de-AT nl en-AU en-GB es-ES fr he hu zh-HK id is it ja ko lt
                             no pl pt-BR ro ru sk sv uk raw].freeze
I18N_SYNC_HINT = '# Refresh with `rake i18n:sync[trmnl_i18n_path,rails_i18n_path]` — do not edit manually.'

# The only number formats number_to_currency and number_with_delimiter read.
NUMBER_FORMATS = %w[currency format].freeze

namespace :i18n do
  desc 'Sync db/data/and_x_more.yml and db/data/locales from trmnl-i18n and rails-i18n checkouts'
  task :sync, %i[trmnl_i18n_path rails_i18n_path] do |_t, args|
    require 'yaml'

    trmnl_i18n_path = args[:trmnl_i18n_path] || ENV.fetch('TRMNL_I18N_SOURCE_REPO') { abort 'Pass the trmnl-i18n path' }
    rails_i18n_path = args[:rails_i18n_path] || ENV.fetch('RAILS_I18N_SOURCE_REPO') { abort 'Pass the rails-i18n path' }
    trmnl_locales_dir = File.join(trmnl_i18n_path, 'lib/trmnl/i18n/locales')
    translations_in = ->(path) { File.exist?(path) ? YAML.load_file(path).values.first : {} }
    write_mirror = lambda do |path, description, data|
      header = "# Mirrored from #{description}.\n#{I18N_SYNC_HINT}\n"
      File.write(File.expand_path(path, __dir__), header + data.to_yaml.delete_prefix("---\n"))
    end

    phrases = Dir.glob("#{trmnl_locales_dir}/plugin_renders/*.yml").filter_map do |file|
      locale, translations = YAML.load_file(file).first
      renders = translations&.dig('renders') || {}
      [locale, renders.values_at('and_x_more_prefix', 'and_x_more_suffix')] if renders['and_x_more_prefix']
    end
    write_mirror.call('db/data/and_x_more.yml', 'trmnl-i18n renders.and_x_more_* (window.I18n.andXMore)', phrases.to_h)

    FileUtils.rm_rf('db/data/locales')
    FileUtils.mkdir_p('db/data/locales')
    TRMNL_AVAILABLE_LOCALES.each do |locale|
      words = translations_in.call("#{trmnl_locales_dir}/custom_plugins/#{locale}.yml").slice('custom_plugins')
      formats = translations_in.call("#{rails_i18n_path}/rails/locale/#{locale}.yml").slice('date', 'time', 'number')
      write_mirror.call("db/data/locales/#{locale}.yml", 'trmnl-i18n custom_plugins and rails-i18n date, time, number',
                        { locale => words.merge(formats, 'number' => formats['number']&.slice(*NUMBER_FORMATS)) })
    end
    puts "Synced db/data/and_x_more.yml and db/data/locales from #{trmnl_i18n_path} and #{rails_i18n_path}"
  end
end
