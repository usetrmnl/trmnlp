# frozen_string_literal: true

require 'spec_helper'
require 'json'

RSpec.describe TRMNLP::OAuth::TokenBundle do
  subject(:bundle) do
    described_class.new(access_token: 'AT', refresh_token: 'RT', expires_at:, token_type: 'Bearer')
  end

  let(:expires_at) { Time.now.to_i + 3600 }

  describe '#expired?' do
    it 'is not expired when the expiry is comfortably ahead' do
      expect(bundle).not_to be_expired
    end

    context 'when the expiry falls inside the refresh buffer' do
      let(:expires_at) { Time.now.to_i + 60 }

      it 'is expired' do
        expect(bundle).to be_expired
      end
    end

    context 'when the expiry is in the past' do
      let(:expires_at) { Time.now.to_i - 10 }

      it 'is expired' do
        expect(bundle).to be_expired
      end
    end

    context 'when there is no expiry' do
      let(:expires_at) { nil }

      it 'never expires' do
        expect(bundle).not_to be_expired
      end
    end
  end

  describe '#merge_refresh' do
    let(:fresh) do
      described_class.new(access_token: 'AT2', refresh_token: 'RT2', expires_at: 999, token_type: 'Bearer')
    end

    it 'takes the refreshed values' do
      expect(bundle.merge_refresh(fresh)).to have_attributes(access_token: 'AT2', refresh_token: 'RT2', expires_at: 999)
    end

    context 'when the refresh omits the refresh_token' do
      let(:fresh) { super().with(refresh_token: nil) }

      it 'keeps the previous refresh_token' do
        expect(bundle.merge_refresh(fresh).refresh_token).to eq('RT')
      end
    end
  end

  describe '.from_h' do
    it 'restores the bundle from its serialized hash' do
      expect(described_class.from_h(JSON.parse(JSON.generate(bundle.to_h)))).to eq(bundle)
    end

    it 'defaults token_type to Bearer when absent' do
      expect(described_class.from_h('access_token' => 'AT').token_type).to eq('Bearer')
    end
  end
end
