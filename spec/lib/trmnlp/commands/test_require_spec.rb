# frozen_string_literal: true

require 'spec_helper'
require 'rspec/core'
require 'trmnlp/commands/test'

RSpec.describe TRMNLP::Commands::Test do
  subject(:command) { described_class.new(context:, options:) }

  let(:options) { described_class::Options.new(dir:, quiet: true, update: false) }

  let(:dir) { File.join(__dir__, '../../../fixtures') }
  let(:context) { TRMNLP::Context.new(dir) }

  before { allow(RSpec::Core::Runner).to receive(:run).and_return(0) }

  it "loads the test helpers by their file, so it works where trmnlp's lib is not on the load path (Docker)" do
    command.call

    expect(RSpec::Core::Runner).to have_received(:run) do |arguments|
      expect(File).to exist(arguments[arguments.index('--require') + 1])
    end
  end
end
