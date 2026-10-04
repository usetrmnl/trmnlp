# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/testing/mock_table'

RSpec.describe TRMNLP::Testing::MockTable do
  subject(:table) { described_class.new(mocks) }

  describe '#answer' do
    context 'with an exact url' do
      let(:mocks) { { 'https://api.test/items' => { json: { n: 1 } } } }

      it 'answers with the json' do
        expect(table.answer('GET', 'https://api.test/items')).to have_attributes(status: 200, body: '{"n":1}')
      end

      it 'ignores the query string unless the key names one' do
        expect(table.answer('GET', 'https://api.test/items?page=2').status).to eq(200)
      end

      it 'answers an unmocked url with 599' do
        expect(table.answer('GET', 'https://api.test/other').status).to eq(599)
      end
    end

    context 'with a wildcard, a regexp, a string body and a method' do
      let(:mocks) do
        { 'https://api.test/*/feed' => 'wild', /calendar\.ics\z/ => 'regexp', 'POST https://api.test/post' => 'posted' }
      end

      it 'matches a wildcard' do
        expect(table.answer('GET', 'https://api.test/a/b/feed').body).to eq('wild')
      end

      it 'matches a regexp' do
        expect(table.answer('GET', 'https://x.test/me/calendar.ics').body).to eq('regexp')
      end

      it 'skips a mock for another method' do
        expect(table.answer('GET', 'https://api.test/post').status).to eq(599)
      end
    end

    context 'with a list of answers' do
      let(:mocks) { { 'https://api.test/a' => [{ status: 500 }, { body: 'ok' }] } }

      it 'uses them in order and repeats the last' do
        expect(Array.new(3) { table.answer('GET', 'https://api.test/a').status }).to eq([500, 200, 200])
      end
    end

    context 'with a lambda' do
      let(:mocks) { { 'https://api.test/*' => ->(request) { { status: 201, body: request[:url] } } } }

      it 'answers with what the lambda returns for the request' do
        expect(table.answer('GET', 'https://api.test/x')).to have_attributes(status: 201, body: 'https://api.test/x')
      end
    end

    context 'with a reset' do
      let(:mocks) { { 'https://api.test/a' => { error: :reset } } }

      it 'answers no response' do
        expect(table.answer('GET', 'https://api.test/a')).to be_nil
      end
    end
  end

  describe 'a slow answer' do
    let(:mocks) { { 'https://api.test/slow' => { body: 'late', delay: 0.2, body_delay: 0.1 } } }

    it 'is recorded while it is still being answered, as a fetch the transform may abandon' do
      thread = Thread.new { table.answer('GET', 'https://api.test/slow', via: :transform) }
      sleep 0.05
      recorded = table.requests.map(&:dup)
      thread.join

      expect(recorded).to contain_exactly(include(url: 'https://api.test/slow', status: nil))
    end

    it 'carries how long to wait between its headers and its body' do
      expect(table.answer('GET', 'https://api.test/slow').body_delay).to eq(0.1)
    end
  end

  describe 'an answer that moves the clock' do
    let(:mocks) { { 'https://api.test/a' => { body: 'ok', advance_clock: 4 } } }
    let(:moved) { [] }

    it 'moves the transform clock by its seconds' do
      described_class.new(mocks, on_advance_clock: ->(seconds) { moved << seconds }).answer('GET', 'https://api.test/a')

      expect(moved).to eq([4])
    end
  end

  describe '#finish' do
    let(:mocks) { { 'https://api.test/a' => 'ok', 'https://api.test/gone' => { error: :reset } } }

    it 'marks a request whose answer was never delivered as aborted' do
      table.answer('GET', 'https://api.test/a', via: :transform)
      table.finish

      expect(table.requests.first).to include(aborted: true)
    end

    it 'leaves a delivered one alone' do
      table.call('GET', 'https://api.test/a', headers: {}, body: nil)
      table.finish

      expect(table.requests.first).to include(aborted: false)
    end

    it 'leaves a reset alone, since the mock dropped it' do
      table.answer('GET', 'https://api.test/gone', via: :transform)
      table.finish

      expect(table.requests.first).to include(aborted: false)
    end
  end

  describe '#call, standing in for OutboundRequest' do
    let(:mocks) { { 'https://api.test/a' => { json: {} }, 'https://api.test/gone' => { error: :reset } } }

    it 'answers the response and no failure' do
      expect(table.call('GET', 'https://api.test/a', headers: {}, body: nil).last).to be_nil
    end

    it 'answers a failure for a reset' do
      expect(table.call('GET', 'https://api.test/gone', headers: {}, body: nil).last).to match(/reset/)
    end

    it 'records the request' do
      table.call('GET', 'https://api.test/a', headers: {}, body: nil)

      expect(table.requests)
        .to contain_exactly(include(method: 'GET', url: 'https://api.test/a', via: :polling, status: 200))
    end
  end
end
