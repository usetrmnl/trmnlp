# frozen_string_literal: true

require 'bundler/setup'
require 'rspec/core/rake_task'
require 'rubocop/rake_task'

RSpec::Core::RakeTask.new { |task| task.verbose = false }
RuboCop::RakeTask.new

task default: :spec

namespace :framework do
  desc 'Sync db/data/framework_versions.yml from a local design-system checkout'
  task :sync, [:source_repo] do |_t, args|
    source_repo = args[:source_repo] || ENV.fetch('FRAMEWORK_SOURCE_REPO', nil)
    if source_repo.nil?
      abort 'Provide the source checkout: rake framework:sync[/path/to/repo] (or FRAMEWORK_SOURCE_REPO=...)'
    end

    source = File.expand_path(File.join(source_repo, 'db', 'data', 'framework_versions.yml'))

    abort "Source file not found: #{source}" unless File.exist?(source)

    destination = File.expand_path('db/data/framework_versions.yml', __dir__)
    contents = File.read(source)
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
