# frozen_string_literal: true

require 'spec_helper'
require 'rspec/core'
require 'trmnlp/commands/test'

RSpec.describe TRMNLP::Commands::Test do
  subject(:command) { described_class.new(context:, options:) }

  let(:options) { described_class::Options.new(dir:, quiet: true, update: false, report: nil) }

  let(:dir) { File.join(__dir__, '../../../fixtures') }
  let(:context) { TRMNLP::Context.new(dir) }

  before { allow(RSpec::Core::Runner).to receive(:run).and_return(0) }

  it "loads the test helpers by their file, so it works where trmnlp's lib is not on the load path (Docker)" do
    command.call

    expect(RSpec::Core::Runner).to have_received(:run) do |arguments|
      expect(File).to exist(arguments[arguments.index('--require') + 1])
    end
  end

  context 'with workers' do
    let(:options) { described_class::Options.new(dir:, quiet: true, update: false, report: nil, workers: 3) }
    let(:parallel) { instance_double(TRMNLP::Testing::Parallel, call: outcome) }
    let(:outcome) { false }

    before do
      require 'trmnlp/testing/parallel'
      allow(TRMNLP::Testing::Parallel).to receive(:new).and_return(parallel)
    end

    it 'shares the examples out over that many' do
      command.call

      expect(TRMNLP::Testing::Parallel).to have_received(:new).with(hash_including(workers: 3))
    end

    it 'answers what the workers found' do
      expect(command.call).to be(false)
    end

    context 'when the examples cannot be shared out' do
      let(:outcome) { nil }

      it 'runs them in this process' do
        command.call

        expect(RSpec::Core::Runner).to have_received(:run)
      end
    end
  end
end
