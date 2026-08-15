# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/layouts_have_content'

RSpec.describe TRMNLP::Lint::Checks::LayoutsHaveContent do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, view_markup: views, shared_markup: '') }

  describe '#issues' do
    context 'when a view and the shared markup are both empty' do
      let(:views) { { 'full' => '' } }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when every view carries enough content' do
      let(:views) { { 'full' => '<p>Real content here</p>' } }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
