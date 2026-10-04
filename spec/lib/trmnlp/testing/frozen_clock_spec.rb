# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/testing/frozen_clock'

RSpec.describe TRMNLP::Testing::FrozenClock do
  let(:time) { Time.utc(2030, 1, 2, 3, 4, 5) }

  describe '.around' do
    it 'answers Time.now with the frozen time inside the block' do
      expect(described_class.around(time) { Time.now }).to eq(time)
    end

    it 'lets the clock run again afterwards' do
      described_class.around(time) { nil }

      expect(Time.now.year).to be < 2030
    end
  end

  describe '.environment' do
    let(:clock_file) { File.join(Dir.mktmpdir, 'clock') }

    before { stub_const('ENV', ENV.to_h.merge('TRMNLP_LIBFAKETIME' => '/lib/faketime.so')) }

    context 'on Linux' do
      before { allow(described_class).to receive(:operating_system).and_return(:linux) }

      it 'preloads libfaketime at the frozen time' do
        expect(described_class.environment(time, clock_file:, interpreter: '/usr/bin/python3'))
          .to include('LD_PRELOAD' => '/lib/faketime.so', 'FAKETIME_TIMESTAMP_FILE' => clock_file, 'TZ' => 'UTC')
      end

      it 'starts the clock file at the frozen time' do
        described_class.environment(time, clock_file:, interpreter: '/usr/bin/python3')

        expect(File.read(clock_file)).to eq("@2030-01-02 03:04:05\n")
      end
    end

    context 'on macOS' do
      before { allow(described_class).to receive(:operating_system).and_return(:darwin) }

      it 'inserts libfaketime for an interpreter outside the protected system paths' do
        expect(described_class.environment(time, clock_file:, interpreter: RbConfig.ruby))
          .to include('DYLD_INSERT_LIBRARIES' => '/lib/faketime.so', 'DYLD_FORCE_FLAT_NAMESPACE' => '1')
      end

      it 'refuses a protected system interpreter, which would silently keep the real time' do
        expect { described_class.environment(time, clock_file:, interpreter: '/bin/sh') }
          .to raise_error(TRMNLP::TestingError, /will not freeze the clock/)
      end
    end

    it 'names how to install libfaketime when it is missing' do
      stub_const('ENV', ENV.to_h.except('TRMNLP_LIBFAKETIME'))
      allow(described_class).to receive_messages(operating_system: :linux)
      stub_const("#{described_class}::LIBRARY_GLOBS", { linux: [] })

      expect { described_class.environment(time, clock_file:, interpreter: 'x') }
        .to raise_error(TRMNLP::TestingError, /apt-get install/)
    end
  end
end
