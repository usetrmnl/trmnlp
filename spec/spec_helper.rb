# frozen_string_literal: true

# Must load before any application code so every line is counted.
require 'simplecov'

SimpleCov.start do
  add_filter '/spec/'
  # Enforce the floor in CI only: a partial local run loads just a few
  # files and would otherwise report a misleadingly low number. Ratchet
  # this upward as coverage improves.
  minimum_coverage 90 if ENV.fetch('CI', false) == 'true'
end

require File.join(__dir__, '../lib/trmnlp')

# See https://rubydoc.info/gems/rspec-core/RSpec/Core/Configuration
RSpec.configure do |config|
  config.color = true
  config.disable_monkey_patching!
  config.example_status_persistence_file_path = './tmp/rspec-examples.txt'
  config.filter_run_when_matching :focus
  config.formatter = ENV.fetch('CI', false) == 'true' ? :progress : :documentation
  config.order = :random
  config.shared_context_metadata_behavior = :apply_to_host_groups

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
    mocks.verify_partial_doubles = true
  end

  Kernel.srand config.seed
end
