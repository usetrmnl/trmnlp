# frozen_string_literal: true

require 'yaml'

require_relative '../select_field_choices'

module TRMNLP
  module Testing
    # The screens a recipe is drawn on: TRMNL's own devices, in landscape and portrait.
    PUBLISHABLE_RECIPE_SCREENS = [
      { device: 'og_png' }, { device: 'og_plus' }, { device: 'og_plus', orientation: :portrait },
      { device: 'v2' }, { device: 'v2', orientation: :portrait }
    ].freeze
    PUBLISHABLE_RECIPE_VIEWS = %w[full half_horizontal half_vertical quadrant].freeze
    PUBLISHABLE_RECIPE_API_FAILURES = {
      'answers with nothing' => { json: {} }, 'answers 500' => { status: 500, body: '' },
      'cannot be reached' => { error: :reset }
    }.freeze
    # A field with more options than this is drawn with its first and last.
    PUBLISHABLE_RECIPE_MAX_OPTIONS = 20

    # Each select field's keyname and the values its options save, from the plugin's settings.yml.
    def self.select_field_values
      path = File.join(plugin_dir, 'src', 'settings.yml')
      fields = File.exist?(path) ? Array(YAML.safe_load_file(path, aliases: true)&.dig('custom_fields')) : []
      fields.select { it['field_type'] == 'select' }.to_h do |field|
        values = SelectFieldChoices.new(field).pairs.map { it.last.to_s }
        [field['keyname'], values.size > PUBLISHABLE_RECIPE_MAX_OPTIONS ? values.values_at(0, -1) : values]
      end
    end
  end
end

# rubocop:disable-next Metrics/BlockLength -- one shared group, one check per example
RSpec.shared_examples 'a publishable recipe' do |screens: TRMNLP::Testing::PUBLISHABLE_RECIPE_SCREENS|
  let(:recipe_inputs) do
    { mocks: respond_to?(:mocks) ? mocks : {}, custom_fields: respond_to?(:custom_fields) ? custom_fields : {},
      variables: respond_to?(:variables) ? variables : {}, now: respond_to?(:now) ? now : nil,
      data: respond_to?(:data) ? data : nil }
  end

  def draw_cleanly = have_no_problems.and(have_no_leaked_text)

  TRMNLP::Testing::PUBLISHABLE_RECIPE_VIEWS.product(screens).each do |view, screen|
    device = screen[:device].is_a?(Hash) ? screen[:device][:model] : screen[:device]
    screen_name = [device, screen[:orientation]].compact.join(' ')

    it "draws the #{view} view on #{screen_name} without page errors" do
      expect(trmnl.render(view:, **screen, **recipe_inputs)).to draw_cleanly
    end
  end

  TRMNLP::Testing::PUBLISHABLE_RECIPE_API_FAILURES.each do |failure, answer|
    it "draws the full view when the API #{failure}" do
      screen = trmnl.render(**screens.first, **recipe_inputs, mocks: { '*' => answer })
      expect(screen).to have_no_problems.and(have_no_leaked_text).and(have_no_transform_error)
    end
  end

  TRMNLP::Testing.select_field_values.each do |keyname, values|
    values.each do |value|
      it "draws the full view with #{keyname} set to #{value}" do
        custom_fields = recipe_inputs[:custom_fields].merge(keyname => value)
        expect(trmnl.render(**screens.first, **recipe_inputs, custom_fields:)).to draw_cleanly
      end
    end
  end

  it 'runs its transform without error' do
    expect(trmnl.transform(device: screens.first[:device], **recipe_inputs).error).to be_nil
  end

  it "stays within TRMNL's serverless limits" do
    expect(trmnl.transform(device: screens.first[:device], **recipe_inputs)).to stay_within_serverless_limits
  end
end
