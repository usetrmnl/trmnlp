# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::WebhookPayload do
  subject(:payload) { described_class.new(body, params) }

  let(:body) { { 'merge_variables' => { 'items' => [3] } } }
  let(:params) { {} }
  let(:stored) { { 'items' => [1, 2], 'title' => 'Old' } }

  describe '#rejection' do
    it 'accepts merge_variables wrapped in an object' do
      expect(payload.rejection).to be_nil
    end

    context 'without the merge_variables wrapper' do
      let(:body) { { 'items' => [3] } }

      it 'asks for the wrapper' do
        expect(payload.rejection).to eq('Must be nested inside a merge_variables payload object')
      end
    end

    context 'with a top-level array' do
      let(:body) { [1, 2] }

      it 'asks for the wrapper' do
        expect(payload.rejection).to eq('Must be nested inside a merge_variables payload object')
      end
    end

    context 'with merge_variables as an array' do
      let(:body) { { 'merge_variables' => [1, 2] } }

      it 'asks for the wrapper' do
        expect(payload.rejection).to eq('Must be nested inside a merge_variables payload object')
      end
    end

    context 'with merge_variables as plain text' do
      let(:body) { { 'merge_variables' => 'hello' } }

      it 'expects an object' do
        expect(payload.rejection).to eq("Received string: 'hello', expecting object")
      end
    end

    context 'with merge_variables as a JSON object in a string' do
      let(:body) { { 'merge_variables' => '{"items":[3]}' } }

      it 'accepts it' do
        expect(payload.rejection).to be_nil
      end
    end

    context 'with merge_variables as a number' do
      let(:body) { { 'merge_variables' => 42 } }

      it 'expects an object' do
        expect(payload.rejection).to eq('Expected an object payload')
      end
    end

    context 'with an unknown merge_strategy' do
      let(:params) { { 'merge_strategy' => 'append' } }

      it 'names the strategy' do
        expect(payload.rejection).to eq("Invalid merge_strategy: 'append'")
      end
    end
  end

  describe '#merged_into' do
    it 'replaces the stored data by default' do
      expect(payload.merged_into(stored)).to eq('items' => [3])
    end

    context 'with merge_variables as a JSON object in a string' do
      let(:body) { { 'merge_variables' => '{"items":[3]}' } }

      it 'parses it' do
        expect(payload.merged_into(stored)).to eq('items' => [3])
      end
    end

    context 'with merge_strategy deep_merge in the body' do
      let(:body) { { 'merge_variables' => { 'items' => [3] }, 'merge_strategy' => 'deep_merge' } }

      it 'keeps the stored keys the post leaves out' do
        expect(payload.merged_into(stored)).to eq('items' => [3], 'title' => 'Old')
      end
    end

    context 'with the legacy deep_merge flag in the query string' do
      let(:params) { { 'deep_merge' => 'true' } }

      it 'deep merges' do
        expect(payload.merged_into(stored)).to eq('items' => [3], 'title' => 'Old')
      end
    end

    context 'with merge_strategy stream' do
      let(:params) { { 'merge_strategy' => 'stream' } }

      it 'appends to stored arrays and drops the keys the post leaves out' do
        expect(payload.merged_into(stored)).to eq('items' => [1, 2, 3])
      end
    end

    context 'with merge_strategy stream and a stream_limit' do
      let(:params) { { 'merge_strategy' => 'stream', 'stream_limit' => '2' } }

      it 'keeps only the newest items' do
        expect(payload.merged_into(stored)).to eq('items' => [2, 3])
      end
    end
  end

  describe '#size_warning' do
    it 'is nil within the 5 kB limit' do
      expect(payload.size_warning('items' => [3])).to be_nil
    end

    it 'names the size above the 5 kB limit' do
      expect(payload.size_warning('text' => 'x' * 5200)).to eq(
        '5211 bytes stored; TRMNL rejects more than 5 kB (10 kB with TRMNL+)'
      )
    end
  end
end
