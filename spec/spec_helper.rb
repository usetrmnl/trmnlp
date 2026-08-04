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

require 'webmock/rspec'
# Block real outbound HTTP in specs, but let rack-test drive the local
# Sinatra app (OAuth route specs) and any other localhost traffic.
WebMock.disable_net_connect!(allow_localhost: true)

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

  # Serves the bundled copy of the framework manifest, so specs assert
  # against a fixed version list instead of whatever is published today.
  config.before do
    stub_request(:get, TRMNLP::FrameworkVersion::MANIFEST_URL)
      .to_return(body: File.read(TRMNLP::FrameworkVersion::DATA_PATH))
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_doubled_constant_names = true
    mocks.verify_partial_doubles = true
  end

  Kernel.srand config.seed
end
