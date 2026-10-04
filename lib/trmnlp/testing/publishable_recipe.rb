# frozen_string_literal: true

module TRMNLP
  module Testing
    # The screens a recipe is drawn on: TRMNL's own devices, in landscape and portrait.
    PUBLISHABLE_RECIPE_SCREENS = [
      { device: 'og_png' }, { device: 'og_plus' }, { device: 'og_plus', orientation: :portrait },
      { device: 'v2' }, { device: 'v2', orientation: :portrait }
    ].freeze
    PUBLISHABLE_RECIPE_VIEWS = %w[full half_horizontal half_vertical quadrant].freeze
  end
end

RSpec.shared_examples 'a publishable recipe' do |screens: TRMNLP::Testing::PUBLISHABLE_RECIPE_SCREENS|
  let(:recipe_inputs) do
    { mocks: respond_to?(:mocks) ? mocks : {}, custom_fields: respond_to?(:custom_fields) ? custom_fields : {} }
  end

  TRMNLP::Testing::PUBLISHABLE_RECIPE_VIEWS.product(screens).each do |view, screen|
    device = screen[:device].is_a?(Hash) ? screen[:device][:model] : screen[:device]
    screen_name = [device, screen[:orientation]].compact.join(' ')

    it "draws the #{view} view on #{screen_name} without overflow or page errors" do
      expect(trmnl.render(view:, **screen, **recipe_inputs)).to have_no_overflow.and have_no_problems
    end
  end

  it 'runs its transform without error' do
    expect(trmnl.transform(device: screens.first[:device], **recipe_inputs).error).to be_nil
  end

  it "stays within TRMNL's serverless limits" do
    expect(trmnl.transform(device: screens.first[:device], **recipe_inputs)).to stay_within_serverless_limits
  end
end
