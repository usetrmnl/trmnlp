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

# A family class after its screen prefixes, captured as the prefixes and the class.
FRAMEWORK_PREFIXED_CLASS = /(?<=\.)((?:[a-z0-9]+\\:)+)((?:value|label|title|description|text|content)--[\w-]+)/

# The screen prefixes a plugins.css defines, grouped by the classes they cover.
def framework_variants(css, classes)
  classes_by_prefix = css.scan(FRAMEWORK_PREFIXED_CLASS)
                         .group_by { |prefix, _| prefix.delete('\\').delete_suffix(':') }
                         .transform_values { |pairs| pairs.map(&:last).uniq.sort }
  variants = classes_by_prefix.group_by(&:last).map do |covered, pairs|
    { 'prefixes' => pairs.map(&:first).sort, 'families' => framework_coverage(covered, classes) }
  end
  variants.sort_by { it['prefixes'].first }
end

# Each family the covered classes belong to, as `all` its classes, all `except` the few
# without the prefixes, or `only` the few with them, whichever list is shorter.
def framework_coverage(covered, classes)
  covered.group_by { it.split('--').first }.sort.to_h do |family, names|
    missing = classes.grep(/\A#{family}--/) - names
    next [family, 'all'] if missing.empty?

    [family, missing.size < names.size ? { 'except' => missing } : { 'only' => names }]
  end
end

namespace :framework do
  desc 'Sync db/data/framework_classes.yml and framework_prefixes.yml from the plugins.css of every release'
  task :classes do
    require 'open-uri'
    require_relative 'lib/trmnlp/framework_version'

    # A family class, bare or after a screen prefix such as `md\:`.
    pattern = /(?<=\.|\\:)(?:value|label|title|description|text|content)--[\w-]+/
    classes_by_release = {}
    variants_by_release = {}
    TRMNLP::FrameworkVersion.version_numbers.sort_by { Gem::Version.new(it) }.each do |number|
      # A class that starts with a digit, such as `1bit:`, is escaped in CSS as `\31 bit\:`.
      css = URI.parse(TRMNLP::FrameworkVersion.new(number).css_url).read.gsub(/\\3(\d) /, '\1')
      classes = css.scan(pattern).uniq.sort
      classes_by_release[number] = classes unless classes == classes_by_release.values.last

      variants = framework_variants(css, classes)
      variants_by_release[number] = variants unless variants == variants_by_release.values.last
    end

    prefixes_destination = File.expand_path('db/data/framework_prefixes.yml', __dir__)
    prefixes_header = <<~HEADER
      # Mirrored from each Framework release's plugins.css: the screen prefixes it defines for
      # value--, label--, title--, description--, text-- and content-- classes, and the classes each
      # covers: every class in a family (`all`), all `except` some, or `only` some. A list holds
      # until the next release listed.
      # Refresh with `rake framework:classes` — do not edit manually.
    HEADER
    File.write(prefixes_destination, prefixes_header + variants_by_release.to_yaml.delete_prefix("---\n"))
    puts "Synced #{prefixes_destination}"

    destination = File.expand_path('db/data/framework_classes.yml', __dir__)
    header = <<~HEADER
      # Mirrored from each Framework release's plugins.css: its value--, label--, title--,
      # description--, text-- and content-- classes. A list holds until the next release listed.
      # Refresh with `rake framework:classes` — do not edit manually.
    HEADER
    File.write(destination, header + classes_by_release.to_yaml.delete_prefix("---\n"))
    puts "Synced #{destination}"
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
