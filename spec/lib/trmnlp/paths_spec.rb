# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe TRMNLP::Paths do
  subject(:paths) { described_class.new(tmp_root) }

  let(:tmp_root) { Dir.mktmpdir('trmnlp-paths-') }

  after { FileUtils.rm_rf(tmp_root) }

  describe '#valid?' do
    it 'is true when .trmnlp.yml exists' do
      File.write(paths.trmnlp_config, '---')
      expect(paths.valid?).to be(true)
    end

    it 'is false when .trmnlp.yml is missing' do
      expect(paths.valid?).to be(false)
    end
  end

  describe '#src_dir / #plugin_config / #template' do
    it 'resolves the canonical project layout' do
      expect(paths.src_dir.to_s).to eq(File.join(tmp_root, 'src'))
      expect(paths.plugin_config.to_s).to eq(File.join(tmp_root, 'src', 'settings.yml'))
      expect(paths.template('full').to_s).to eq(File.join(tmp_root, 'src', 'full.liquid'))
      expect(paths.shared_template.to_s).to eq(File.join(tmp_root, 'src', 'shared.liquid'))
    end
  end

  describe '#transform_file' do
    let(:src) { File.join(tmp_root, 'src') }
    before { FileUtils.mkdir_p(src) }

    it 'returns [nil, nil] when no transform exists' do
      expect(paths.transform_file).to eq([nil, nil])
    end

    it 'detects transform.py as python' do
      FileUtils.touch(File.join(src, 'transform.py'))
      path, language = paths.transform_file
      expect(path.basename.to_s).to eq('transform.py')
      expect(language).to eq('python')
    end

    it 'detects transform.rb as ruby' do
      FileUtils.touch(File.join(src, 'transform.rb'))
      _, language = paths.transform_file
      expect(language).to eq('ruby')
    end

    it 'detects transform.js as node' do
      FileUtils.touch(File.join(src, 'transform.js'))
      _, language = paths.transform_file
      expect(language).to eq('node')
    end

    it 'detects transform.php as php' do
      FileUtils.touch(File.join(src, 'transform.php'))
      _, language = paths.transform_file
      expect(language).to eq('php')
    end
  end

  describe '#expand' do
    it 'resolves a relative path against the project root' do
      expect(paths.expand('src').to_s).to eq(File.join(tmp_root, 'src'))
    end

    it 'leaves an absolute path unchanged' do
      expect(paths.expand('/tmp/elsewhere').to_s).to eq('/tmp/elsewhere')
    end
  end
end
