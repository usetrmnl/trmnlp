# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/custom_field_links_embedded'

RSpec.describe TRMNLP::Lint::Checks::CustomFieldLinksEmbedded do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, custom_field_definitions: [field]) }
  let(:field) { { 'keyname' => 'api_key', 'field_type' => 'string', 'name' => 'API Key' }.merge(description) }

  def message(key, url)
    "Custom field 'api_key' #{key} has a plain link, #{url}. Embed it as " \
      "<a href=\"#{url}\" class=\"underline\">, or remove https:// if it is only an example."
  end

  describe '#issues' do
    context 'with a plain https link in the description' do
      let(:description) { { 'description' => 'Get your key at https://somewhere.com/settings.' } }

      it 'reports the link' do
        expect(check.issues).to eq([{ message: message('description', 'https://somewhere.com/settings'),
                                      learn_more: described_class::LEARN_MORE }])
      end
    end

    context 'with a plain https link in a localized description' do
      let(:description) { { 'description-fr' => 'Votre clé : https://somewhere.com/settings' } }

      it 'reports the link under that key' do
        expect(check.issues.map { it[:message] }).to eq([message('description-fr', 'https://somewhere.com/settings')])
      end
    end

    context 'with the link embedded in an anchor' do
      let(:description) do
        { 'description' => 'Get your key from <a href="https://somewhere.com/settings">Server Settings</a>.' }
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with an anchor whose text is the URL' do
      let(:description) do
        { 'description' => '<a href="https://somewhere.com" class="underline">https://somewhere.com</a>' }
      end

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with an example link written without https://' do
      let(:description) { { 'description' => 'For example, somewhere.com/feed.json' } }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a link outside the description' do
      let(:description) { { 'placeholder' => 'https://somewhere.com/feed.json' } }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
