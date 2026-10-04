# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/testing/memory_sampler'

RSpec.describe TRMNLP::Testing::MemorySampler do
  it 'answers the peak memory of a process, in megabytes' do
    pid = Process.spawn(RbConfig.ruby, '-e', 'buffer = "a" * 60_000_000; sleep 0.4; buffer.size')
    sampler = described_class.start(pid)
    Process.wait(pid)

    expect(sampler.peak_mb).to be_between(50, 200)
  end

  it 'answers nil for a process it never saw' do
    expect(described_class.start(999_999).peak_mb).to be_nil
  end
end
