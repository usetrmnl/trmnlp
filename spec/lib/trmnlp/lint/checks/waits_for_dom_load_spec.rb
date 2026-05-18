# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/waits_for_dom_load'

RSpec.describe TRMNLP::Lint::Checks::WaitsForDomLoad do
  subject(:check) { described_class.new(source) }

  let(:source) { instance_double(TRMNLP::Lint::Source, all_markup: markup) }

  describe '#issues' do
    context 'when the markup hooks the window load event' do
      let(:markup) { '<script>window.onload = init</script>' }

      it 'reports the issue' do
        expect(check.issues).not_to be_empty
      end
    end

    context 'when the markup listens for DOMContentLoaded' do
      let(:markup) { '<script>document.addEventListener("DOMContentLoaded", init)</script>' }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
