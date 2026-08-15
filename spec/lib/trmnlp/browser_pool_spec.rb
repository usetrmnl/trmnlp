# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/browser_pool'

RSpec.describe TRMNLP::BrowserPool do
  subject(:pool) { described_class.new(driver_factory:, max_size: 2) }

  let(:built_drivers) { [] }
  let(:driver_factory) { -> { FakeDriver.new.tap { |d| built_drivers << d } } }

  class FakeDriver
    attr_accessor :title_raises, :quit_called

    def title
      raise 'driver dead' if title_raises

      'ok'
    end

    def quit
      @quit_called = true
    end
  end

  describe '#with_driver' do
    it 'yields a driver from the factory' do
      yielded = nil
      pool.with_driver { |d| yielded = d }

      expect(yielded).to be(built_drivers.first)
    end

    it 'reuses the same driver on a second sequential call' do
      pool.with_driver { |_| }
      pool.with_driver { |_| }

      expect(built_drivers.size).to eq(1)
    end

    it 'returns the driver to the pool even when the block raises' do
      expect { pool.with_driver { raise 'boom' } }.to raise_error('boom')

      pool.with_driver { |_| }
      expect(built_drivers.size).to eq(1)
    end

    it 'recycles the driver when the health check raises' do
      pool.with_driver { |d| d.title_raises = true }
      pool.with_driver { |_| }

      expect(built_drivers.size).to eq(2)
    end
  end

  describe '#shutdown' do
    it 'quits every driver built by the pool' do
      pool.with_driver { |_| }
      pool.shutdown

      expect(built_drivers.first.quit_called).to be(true)
    end

    it 'is idempotent' do
      pool.with_driver { |_| }
      pool.shutdown

      expect { pool.shutdown }.not_to raise_error
    end

    it 'swallows quit errors so one bad driver does not block the rest' do
      pool.with_driver { |_| }
      allow(built_drivers.first).to receive(:quit).and_raise('detached')

      expect { pool.shutdown }.not_to raise_error
    end
  end
end
