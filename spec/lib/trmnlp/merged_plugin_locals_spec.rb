# frozen_string_literal: true

require 'spec_helper'

RSpec.describe TRMNLP::MergedPluginLocals do
  subject(:merged_plugin_locals) { described_class.new(config:, paths:) }

  let(:root_dir) { Pathname.new(Dir.mktmpdir) }
  let(:paths) { TRMNLP::Paths.new(root_dir.join('merge')) }
  let(:config) { TRMNLP::Config.new(paths) }
  let(:merge_fields) { [{ 'keyname' => 'my_weather', 'field_type' => 'plugin_instance_select' }] }
  let(:merge_values) { { 'my_weather' => 'private_plugin_42' } }
  let(:weather_settings) do
    { 'strategy' => 'static', 'static_data' => '{"temp":21}',
      'custom_fields' => [{ 'keyname' => 'city' }, { 'keyname' => 'api_key', 'field_type' => 'password' }] }
  end
  let(:weather_locals) do
    { 'merge_variables' => { 'temp' => 21 }, 'custom_fields_values' => { 'city' => 'Paris' } }
  end

  def write_project(dir, project, settings)
    root_dir.join(dir, 'src').mkpath
    root_dir.join(dir, '.trmnlp.yml').write(YAML.dump(project))
    root_dir.join(dir, 'src', 'settings.yml').write(YAML.dump(settings))
  end

  before do
    write_project('weather', { 'custom_fields' => { 'city' => 'Paris', 'api_key' => 'secret' } }, weather_settings)
    merge_project = { 'merged_plugins' => { 'private_plugin_42' => '../weather' }, 'custom_fields' => merge_values }
    write_project('merge', merge_project, { 'strategy' => 'plugin_merge', 'custom_fields' => merge_fields })
  end

  after { FileUtils.remove_entry(root_dir) }

  it "keys each plugin's locals by its keyname and id, leaving out secret fields" do
    expect(merged_plugin_locals.call['private_plugin_42']).to eq(weather_locals)
  end

  it 'copies the plugin a plugin_instance_select field selects under the field keyname' do
    expect(merged_plugin_locals.call['my_weather']).to eq(weather_locals)
  end

  context 'when a selection names no listed plugin' do
    let(:merge_values) { { 'my_weather' => 'private_plugin_7' } }

    it 'leaves the field keyname out' do
      expect(merged_plugin_locals.call).not_to have_key('my_weather')
    end
  end

  context 'when the plugin has no custom field values' do
    let(:weather_settings) { { 'strategy' => 'static', 'static_data' => '{"temp":21}' } }

    before { root_dir.join('weather', '.trmnlp.yml').write('---') }

    it 'answers only its merge_variables' do
      expect(merged_plugin_locals.call['private_plugin_42']).to eq('merge_variables' => { 'temp' => 21 })
    end
  end

  it 'raises when a listed directory is not a trmnlp project' do
    root_dir.join('weather', '.trmnlp.yml').delete

    expect { merged_plugin_locals.call }.to raise_error(TRMNLP::NotAPlugin)
  end
end
