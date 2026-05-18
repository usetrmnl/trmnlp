# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::Watcher do
  subject(:watcher) { described_class.new(config:, user_data_assembler:, transform_pipeline:) }

  let(:root_dir) { File.join(__dir__, '../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:transform_pipeline) { TRMNLP::TransformPipeline.new(config:, paths:) }
  let(:user_data_assembler) { TRMNLP::UserDataAssembler.new(config:, paths:, transform_pipeline:) }

  describe '#start' do
    # NOTE: stubbing Thread.new prevents the filewatcher loop from spawning —
    # the watch loop is intentionally untested (background-thread non-determinism
    # is not worth the flake risk for a smoke spec).
    let(:fake_thread) { instance_double(Thread) }

    before { allow(Thread).to receive(:new).and_return(fake_thread) }

    it 'spawns a thread on first call' do
      expect(watcher.start).to be(fake_thread)
      expect(Thread).to have_received(:new).once
    end

    it 'returns the same thread on subsequent calls (idempotent)' do
      first = watcher.start
      second = watcher.start

      expect(second).to be(first)
      expect(Thread).to have_received(:new).once
    end
  end

  describe '#on_change' do
    # NOTE: the callback is stored in an ivar and consumed inside the private
    # notify path. Asserting on the ivar is the cheapest way to confirm the
    # public setter does what it advertises without driving the filewatcher.
    it 'stores the supplied block as the view-change callback' do
      block = proc { |view, data| [view, data] }

      watcher.on_change(&block)

      expect(watcher.instance_variable_get(:@view_change_callback)).to be(block)
    end
  end
end
