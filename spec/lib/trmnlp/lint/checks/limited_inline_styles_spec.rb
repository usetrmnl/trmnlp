# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/limited_inline_styles'

RSpec.describe TRMNLP::Lint::Checks::LimitedInlineStyles do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }

  describe '#issues' do
    context 'when the markup leans on more inline style properties than allowed' do
      let(:markup) do
        '<div style="padding:1px;margin:1px;font-size:1px;text-align:left;' \
          'background-color:red;border-radius:1px;object-fit:cover">busy</div>'
      end

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the markup uses few inline style properties' do
      let(:markup) { '<div style="padding: 1em">tidy</div>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
