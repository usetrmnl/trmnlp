require 'spec_helper'
require 'trmnlp/commands'

RSpec.describe TRMNLP::Commands::Init do
  let(:tmpdir) { Dir.mktmpdir }
  let(:project_name) { 'test_plugin' }
  let(:dest_dir) { File.join(tmpdir, project_name) }

  subject(:command) { described_class.new(dir: tmpdir, quiet: true) }

  after { FileUtils.rm_rf(tmpdir) }

  it 'creates the project directory' do
    command.call(project_name)
    expect(Dir.exist?(dest_dir)).to be true
  end

  it 'copies .trmnlp.yml into the project' do
    command.call(project_name)
    expect(File.exist?(File.join(dest_dir, '.trmnlp.yml'))).to be true
  end

  it 'copies src/settings.yml' do
    command.call(project_name)
    expect(File.exist?(File.join(dest_dir, 'src', 'settings.yml'))).to be true
  end

  it 'copies liquid templates' do
    command.call(project_name)
    expect(File.exist?(File.join(dest_dir, 'src', 'full.liquid'))).to be true
    expect(File.exist?(File.join(dest_dir, 'src', 'half_horizontal.liquid'))).to be true
    expect(File.exist?(File.join(dest_dir, 'src', 'half_vertical.liquid'))).to be true
    expect(File.exist?(File.join(dest_dir, 'src', 'quadrant.liquid'))).to be true
  end

  context 'with skip_liquid: true' do
    subject(:command) { described_class.new(dir: tmpdir, quiet: true, skip_liquid: true) }

    it 'skips .liquid files but copies other files' do
      command.call(project_name)
      expect(File.exist?(File.join(dest_dir, '.trmnlp.yml'))).to be true
      expect(File.exist?(File.join(dest_dir, 'src', 'settings.yml'))).to be true
      expect(File.exist?(File.join(dest_dir, 'src', 'full.liquid'))).to be false
    end
  end
end
