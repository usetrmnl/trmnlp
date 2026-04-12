require 'spec_helper'
require 'trmnlp/commands'

RSpec.describe TRMNLP::Commands::Build do
  let(:tmpdir) { Dir.mktmpdir }
  let(:build_dir) { File.join(tmpdir, '_build') }

  subject(:command) { described_class.new(dir: tmpdir, quiet: true) }

  before do
    # Set up a minimal plugin directory
    FileUtils.mkdir_p(File.join(tmpdir, 'src'))
    File.write(File.join(tmpdir, '.trmnlp.yml'), '')
    File.write(File.join(tmpdir, 'src', 'settings.yml'), "strategy: static\nstatic_data: '{\"msg\": \"built\"}'")

    TRMNLP::VIEWS.each do |view|
      File.write(File.join(tmpdir, 'src', "#{view}.liquid"), "<p>{{ msg }}</p>")
    end
  end

  after { FileUtils.rm_rf(tmpdir) }

  it 'creates the _build directory' do
    command.call
    expect(Dir.exist?(build_dir)).to be true
  end

  it 'writes an HTML file for each view' do
    command.call
    TRMNLP::VIEWS.each do |view|
      path = File.join(build_dir, "#{view}.html")
      expect(File.exist?(path)).to be true
      content = File.read(path)
      expect(content).to include('<!DOCTYPE html>')
      expect(content).to include('built')
    end
  end
end
