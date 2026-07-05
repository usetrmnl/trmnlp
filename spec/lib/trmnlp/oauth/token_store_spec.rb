# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'fileutils'

RSpec.describe TRMNLP::OAuth::TokenStore do
  subject(:store) { described_class.new(path) }

  let(:tmpdir) { Pathname(Dir.mktmpdir) }
  let(:path) { tmpdir.join('oauth', 'tokens.json') }
  let(:bundle) do
    TRMNLP::OAuth::TokenBundle.new(access_token: 'at', refresh_token: 'rt', expires_at: 123, token_type: 'Bearer')
  end

  after { FileUtils.remove_entry(tmpdir) if tmpdir.exist? }

  describe '#read' do
    it 'returns nil when no file has been written' do
      expect(store.read).to be_nil
    end

    context 'after writing a bundle' do
      before { store.write(bundle) }

      it 'returns the stored bundle' do
        expect(store.read).to eq(bundle)
      end
    end
  end

  describe '#write' do
    before { store.write(bundle) }

    it 'creates the parent directory' do
      expect(path.dirname).to be_directory
    end

    it 'writes the file readable only by the owner' do
      expect(path.stat.mode & 0o777).to eq(0o600)
    end
  end

  describe '#clear' do
    before do
      store.write(bundle)
      store.clear
    end

    it 'removes the stored bundle' do
      expect(store.read).to be_nil
    end
  end
end
