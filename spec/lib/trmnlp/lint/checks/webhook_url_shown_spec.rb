# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/webhook_url_shown'

RSpec.describe TRMNLP::Lint::Checks::WebhookUrlShown do
  subject(:check) { described_class.new(source) }

  let(:source) do
    instance_double(TRMNLP::Lint::Source, settings: { 'strategy' => strategy }, custom_field_definitions: definitions)
  end
  let(:author_bio) { { 'keyname' => 'about', 'field_type' => 'author_bio', 'name' => 'About' } }
  let(:webhook_url) { { 'keyname' => 'webhook_url', 'field_type' => 'copyable_webhook_url', 'name' => 'Webhook URL' } }

  describe '#issues' do
    context 'with a webhook recipe that has a copyable_webhook_url field' do
      let(:strategy) { 'webhook' }
      let(:definitions) { [author_bio, webhook_url] }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a webhook recipe that has no copyable_webhook_url field' do
      let(:strategy) { 'webhook' }
      let(:definitions) { [author_bio, { 'keyname' => 'url', 'field_type' => 'copyable', 'name' => 'URL' }] }

      it 'reports the issue' do
        expect(check.issues).to eq([{ message: described_class::MESSAGE, learn_more: described_class::LEARN_MORE }])
      end
    end

    context 'with a webhook recipe that has no custom fields' do
      let(:strategy) { 'webhook' }
      let(:definitions) { [] }

      it 'reports the issue' do
        expect(check.issues.size).to eq(1)
      end
    end

    %w[polling static plugin_merge].each do |other|
      context "with a #{other} recipe" do
        let(:strategy) { other }
        let(:definitions) { [author_bio] }

        it 'passes' do
          expect(check.issues).to be_empty
        end
      end
    end
  end
end
