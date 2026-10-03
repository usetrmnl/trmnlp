# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::WebhookReceiver do
  subject(:receiver) { described_class.new(paths:, transform_pipeline:, user_data_assembler:, reporter:) }

  let(:paths) { TRMNLP::Paths.new(File.join(__dir__, '../../fixtures')) }
  let(:transform_pipeline) { instance_double(TRMNLP::TransformPipeline, configured?: false, error: nil) }
  let(:user_data_assembler) { instance_double(TRMNLP::UserDataAssembler) }
  let(:reporter) { instance_spy(TRMNLP::Reporter, yellow: 'warned') }
  let(:cache_dir) { Pathname.new(Dir.mktmpdir) }
  let(:stored) { JSON.parse(paths.user_data.read) }

  before do
    allow(paths).to receive(:cache_dir).and_return(cache_dir)
    paths.user_data.dirname.mkpath
    paths.user_data.write('{"items":[1],"title":"Old"}')
  end

  after { FileUtils.remove_entry(cache_dir) }

  it 'stores merge_variables in place of the stored data' do
    receiver.call('{"merge_variables":{"items":[2]}}')

    expect(stored).to eq('items' => [2])
  end

  it 'answers 200 with the stored merge_variables' do
    expect(receiver.call('{"merge_variables":{"items":[2]}}')).to eq([200,
                                                                      { message: nil,
                                                                        merge_variables: { 'items' => [2] } }])
  end

  it 'applies the merge_strategy from the query string' do
    receiver.call('{"merge_variables":{"items":[2]}}', 'merge_strategy' => 'stream')

    expect(stored).to eq('items' => [1, 2])
  end

  it 'stores an oversized post and warns about it' do
    receiver.call(JSON.generate('merge_variables' => { 'text' => 'x' * 5200 }))

    expect(reporter).to have_received(:yellow).with(
      'webhook warning: 5211 bytes stored; TRMNL rejects more than 5 kB (10 kB with TRMNL+)'
    )
  end

  context 'when the post is rejected' do
    let(:response) { receiver.call('{"items":[2]}') }

    it 'answers 422 with the reason and the stored data' do
      expect(response).to eq(
        [422, { message: 'Must be nested inside a merge_variables payload object',
                merge_variables: { 'items' => [1], 'title' => 'Old' } }]
      )
    end

    it 'keeps the stored data' do
      response

      expect(stored).to eq('items' => [1], 'title' => 'Old')
    end

    it 'reports the reason' do
      response

      expect(reporter).to have_received(:yellow)
        .with('webhook warning: Must be nested inside a merge_variables payload object')
    end
  end

  it 'answers an empty list for merge_variables when nothing is stored and none were posted, as TRMNL does' do
    paths.user_data.delete

    expect(receiver.call('{"items":[2]}').last[:merge_variables]).to eq([])
  end

  it 'answers 400 to a body that is not JSON' do
    expect(receiver.call('not json').first).to eq(400)
  end

  context 'with a serverless transform' do
    let(:transform_pipeline) { instance_double(TRMNLP::TransformPipeline, configured?: true, error: nil) }

    before do
      allow(user_data_assembler).to receive(:transform_webhook_post)
        .with({ 'items' => [2] }).and_return('items' => [20])
    end

    it 'stores the transform output' do
      receiver.call('{"merge_variables":{"items":[2]}}')

      expect(stored).to eq('items' => [20])
    end

    it 'merges the transform output under the merge_strategy' do
      receiver.call('{"merge_variables":{"items":[2]}}', 'merge_strategy' => 'stream')

      expect(stored).to eq('items' => [1, 20])
    end

    it 'answers 200 with the posted merge_variables, as TRMNL does before its transform runs' do
      expect(receiver.call('{"merge_variables":{"items":[2]}}')).to eq(
        [200, { message: nil, merge_variables: { 'items' => [2] }, processing: 'serverless' }]
      )
    end

    it 'refuses a post over 1 MB before running the transform' do
      expect(receiver.call(JSON.generate('merge_variables' => { 'text' => 'x' * (1024 * 1024) })).first).to eq(422)
    end
  end

  context 'when the serverless transform fails' do
    let(:transform_pipeline) { instance_double(TRMNLP::TransformPipeline, configured?: true, error: 'boom') }

    before { allow(user_data_assembler).to receive(:transform_webhook_post).and_return('items' => [2]) }

    it 'keeps the stored data' do
      receiver.call('{"merge_variables":{"items":[2]}}')

      expect(stored).to eq('items' => [1], 'title' => 'Old')
    end

    it 'reports the failure' do
      receiver.call('{"merge_variables":{"items":[2]}}')

      expect(reporter).to have_received(:yellow).with('webhook warning: Transform failed: boom')
    end
  end
end
