# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/image_links_reachable'

RSpec.describe TRMNLP::Lint::Checks::ImageLinksReachable do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }
  let(:markup) { '<img src="https://example.com/logo.png">' }

  describe '#issues' do
    context 'when the image host is unreachable' do
      before { allow(Net::HTTP).to receive(:start).and_raise(SocketError) }

      it 'skips the check rather than blaming the plugin' do
        expect(check.issues).to be_empty
      end
    end

    context 'when the image responds with a 404' do
      before do
        allow(Net::HTTP).to receive(:start).and_return(Net::HTTPNotFound.new('1.1', '404', 'Not Found'))
      end

      it 'reports the unreachable image' do
        expect(check.issues).not_to be_empty
      end
    end
  end
end
