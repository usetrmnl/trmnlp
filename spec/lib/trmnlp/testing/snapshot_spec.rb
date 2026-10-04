# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/testing/screen'
require 'trmnlp/testing/snapshot'

RSpec.describe TRMNLP::Testing::Snapshot do
  subject(:snapshot) { described_class.new(screen, name: 'case', dir:) }

  let(:dir) { Dir.mktmpdir('trmnlp-snapshots-') }
  let(:screen) { instance_double(TRMNLP::Testing::Screen, png_path: png('white')) }

  let(:environment) { {} }

  before { stub_const('ENV', ENV.to_h.except('CI', 'TRMNLP_UPDATE_SNAPSHOTS').merge(environment)) }

  after { FileUtils.remove_entry(dir) }

  def png(color, size: '10x10')
    path = File.join(Dir.mktmpdir('trmnlp-png-'), "#{color}.png")
    MiniMagick::Tool.new('convert') { |convert| convert << '-size' << size << "xc:#{color}" << path }
    path
  end

  def store(path)
    FileUtils.mkdir_p(File.dirname(snapshot.path))
    FileUtils.cp(path, snapshot.path)
  end

  it 'stores a missing snapshot and passes' do
    expect([snapshot.mismatch, File.exist?(snapshot.path)]).to eq([nil, true])
  end

  it 'stores a snapshot others can read, though the screen is private to its run' do
    File.chmod(0o600, screen.png_path)
    snapshot.mismatch

    expect(File.stat(snapshot.path).mode & 0o044).to eq(0o044)
  end

  context 'on CI' do
    let(:environment) { { 'CI' => 'true' } }

    it 'fails a missing snapshot' do
      expect(snapshot.mismatch).to match(/no snapshot/)
    end
  end

  it 'passes an identical screen' do
    store(screen.png_path)

    expect(snapshot.mismatch).to be_nil
  end

  it 'counts the pixels that differ' do
    store(png('black'))

    expect(snapshot.mismatch).to start_with('100 pixels differ')
  end

  it 'fails a screen of another size' do
    store(png('white', size: '20x10'))

    expect(snapshot.mismatch).to start_with('all pixels differ')
  end

  context 'when asked to update' do
    let(:environment) { { 'TRMNLP_UPDATE_SNAPSHOTS' => '1' } }

    it 'rewrites the snapshot' do
      store(png('black'))

      expect(snapshot.mismatch).to be_nil
    end
  end
end
