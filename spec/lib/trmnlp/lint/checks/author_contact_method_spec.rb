# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/author_contact_method'

RSpec.describe TRMNLP::Lint::Checks::AuthorContactMethod do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, custom_field_definitions: definitions) }
  let(:definitions) { [{ 'keyname' => 'about', 'field_type' => 'author_bio', 'name' => 'About' }.merge(contact)] }

  describe '#issues' do
    shared_examples 'a recipe with a contact method' do
      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    shared_examples 'a recipe without a contact method' do
      it 'reports the issue' do
        expect(check.issues).to eq([{ message: described_class::MESSAGE, learn_more: described_class::LEARN_MORE }])
      end
    end

    context 'with an email address' do
      let(:contact) { { 'email_address' => 'me@example.com' } }

      it_behaves_like 'a recipe with a contact method'
    end

    context 'with a GitHub link' do
      let(:contact) { { 'github_url' => 'https://github.com/me/plugin' } }

      it_behaves_like 'a recipe with a contact method'
    end

    context 'with a web link' do
      let(:contact) { { 'learn_more_url' => 'https://example.com' } }

      it_behaves_like 'a recipe with a contact method'
    end

    context 'with an email address in the description' do
      let(:contact) { { 'description' => 'Questions? Write to me@example.com.' } }

      it_behaves_like 'a recipe with a contact method'
    end

    context 'with a web link in the description' do
      let(:contact) { { 'description' => 'Issues go to https://example.com/issues' } }

      it_behaves_like 'a recipe with a contact method'
    end

    context 'with only a Discord link' do
      let(:contact) { { 'learn_more_url' => 'https://discord.gg/abc', 'description' => 'https://discord.com/users/1' } }

      it_behaves_like 'a recipe without a contact method'
    end

    context 'with only a Discord handle' do
      let(:contact) { { 'description' => 'Find me on Discord as @me.' } }

      it_behaves_like 'a recipe without a contact method'
    end

    context 'with blank contact keys' do
      let(:contact) { { 'email_address' => ' ', 'github_url' => '', 'description' => nil } }

      it_behaves_like 'a recipe without a contact method'
    end

    context 'without an author_bio field' do
      let(:definitions) { [{ 'keyname' => 'api_key', 'field_type' => 'string', 'description' => 'me@example.com' }] }

      it_behaves_like 'a recipe without a contact method'
    end

    context 'without custom fields' do
      let(:definitions) { [] }

      it_behaves_like 'a recipe without a contact method'
    end
  end
end
