# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/oauth_lists_optional'

RSpec.describe TRMNLP::Lint::Checks::OauthListsOptional do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, custom_field_definitions: [field]) }
  let(:remote) do
    { 'url' => 'https://api.example.com/accounts',
      'headers' => { 'Authorization' => 'Bearer {{ oauth_access_token }}' },
      'response_path' => 'accounts', 'label_field' => 'name', 'value_field' => 'id' }
  end
  let(:account) { { 'keyname' => 'account', 'field_type' => 'xhrSelect', 'name' => 'Account', 'remote' => remote } }

  describe '#issues' do
    context 'with a required xhrSelect that lists with the OAuth token' do
      let(:field) { account }

      it 'reports the field' do
        expect(check.issues).to match([{ message: a_string_starting_with("Form field 'account' lists its options"),
                                         learn_more: described_class::LEARN_MORE }])
      end
    end

    context 'with a required xhrSelectSearch that sends the token in its url' do
      let(:field) do
        account.merge('field_type' => 'xhrSelectSearch',
                      'remote' => { 'url' => 'https://api.example.com/search?token={{oauth_access_token}}' })
      end

      it 'reports the field' do
        expect(check.issues.size).to eq(1)
      end
    end

    {
      'it is optional' => { 'optional' => true },
      'it has a default' => { 'default' => 'me' },
      'its list needs no OAuth token' => { 'remote' => { 'url' => 'https://api.example.com/accounts' } },
      'it is not an xhr list' => { 'field_type' => 'string', 'remote' => nil }
    }.each do |reason, changes|
      context "with an account field when #{reason}" do
        let(:field) { account.merge(changes) }

        it 'passes' do
          expect(check.issues).to be_empty
        end
      end
    end
  end
end
