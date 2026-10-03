# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::AsyncCallback do
  subject(:callback) { described_class.new(config:, paths:, reporter:) }

  let(:paths) { TRMNLP::Paths.new(File.join(__dir__, '../../fixtures')) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:reporter) { TRMNLP::Reporter.new(quiet: true) }
  let(:cache_dir) { Pathname.new(Dir.mktmpdir) }
  let(:stored) { JSON.parse(paths.user_data.read) }
  let(:post) { '{"merge_variables":{"items":[2]}}' }

  before do
    allow(paths).to receive(:cache_dir).and_return(cache_dir)
    allow(config.plugin).to receive(:async_polling?).and_return(true)
    callback.server_url = 'http://localhost:4567'
  end

  after { FileUtils.remove_entry(cache_dir) }

  describe '#start' do
    it 'answers a callback url carrying the next version' do
      callback.start

      expect(callback.start).to eq('http://localhost:4567/callback?v=2')
    end

    it 'awaits the callback' do
      callback.start

      expect(callback).to be_awaiting
    end
  end

  describe '#call' do
    before { callback.start }

    it 'stores the posted merge_variables' do
      callback.call(post, '1')

      expect(stored).to eq('items' => [2])
    end

    it 'answers 200 ok' do
      expect(callback.call(post, '1')).to eq([200, { status: 'ok' }])
    end

    it 'stops awaiting once the data arrives' do
      callback.call(post, '1')

      expect(callback).not_to be_awaiting
    end

    it 'answers 410 to a second post of the same version' do
      callback.call(post, '1')

      expect(callback.call(post, '1')).to eq([410, { message: 'No pending async request' }])
    end

    it 'answers 410 to an older version' do
      callback.start

      expect(callback.call(post, '1')).to eq([410, { message: 'Version mismatch' }])
    end

    it 'answers 410 after 15 minutes' do
      allow(Time).to receive(:now).and_return(Time.now + (16 * 60))

      expect(callback.call(post, '1')).to eq([410, { message: 'Async request expired' }])
    end

    it 'answers 410 when the plugin is not async_polling' do
      allow(config.plugin).to receive(:async_polling?).and_return(false)

      expect(callback.call(post, '1')).to eq([410, { message: 'Strategy is not async_polling' }])
    end

    it 'answers 422 to data outside merge_variables' do
      expect(callback.call('{"items":[2]}', '1'))
        .to eq([422, { message: 'Must be nested inside a merge_variables payload object' }])
    end

    it 'answers 400 to a body that is not JSON' do
      expect(callback.call('not json', '1').first).to eq(400)
    end

    it 'warns about a post TRMNL may find too large' do
      callback.call(JSON.generate('merge_variables' => { 'text' => 'x' * 5200 }), '1')

      expect(reporter.messages).to include(a_string_matching(/callback warning: 5211 bytes stored/))
    end

    it 'reports a refused post' do
      callback.call(post, '7')

      expect(reporter.messages).to include('callback warning: Version mismatch')
    end
  end
end
