# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNL::Liquid do
  describe 'registered filters' do
    it 'renders pluralize from the bundled filter set' do
      environment = described_class.new
      template = Liquid::Template.parse(%q({{ "person" | pluralize: 4, plural: 'people' }}), environment:)

      expect(template.render).to eq('4 people')
    end
  end
end
