# frozen_string_literal: true

require 'spec_helper'
require 'trmnlp/random_number'

RSpec.describe TRMNLP::RandomNumber do
  def render(markup) = Liquid::Template.parse(markup, environment: TRMNL::Liquid.new).render

  it 'draws a number between the bounds, as TRMNL does' do
    expect(render('{{ 0 | random_number: 3, 3 }}')).to eq('3')
  end

  it 'draws from 0 up to one bound' do
    expect(render('{{ 0 | random_number: 0 }}')).to eq('0')
  end

  it 'draws from 0 to 100 with no bounds' do
    expect(render('{{ 0 | random_number }}').to_i).to be_between(0, 100)
  end
end
