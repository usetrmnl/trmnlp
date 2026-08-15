# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'zip'
require 'trmnlp/commands/pull'

RSpec.describe TRMNLP::Commands::Pull do
  subject(:command) do
    described_class.new(context:,
                        options: described_class::Options.new(dir: tmp_root, quiet: true,
                                                              force: true, id: '42'))
  end

  let(:tmp_root) { Dir.mktmpdir('trmnlp-pull-') }
  let(:context) { TRMNLP::Context.new(tmp_root) }
  let(:api_client) { instance_double(TRMNLP::APIClient) }
  let(:archive_tempfile) { build_zip_tempfile('settings.yml' => "---\nname: pulled\n") }

  before do
    File.write(File.join(tmp_root, '.trmnlp.yml'), '---')
    allow(context.config.app).to receive(:logged_in?).and_return(true)
    allow(TRMNLP::APIClient).to receive(:new).and_return(api_client)
  end

  after do
    archive_tempfile.close
    FileUtils.rm_f(archive_tempfile.path)
    FileUtils.rm_rf(tmp_root)
  end

  describe '#call' do
    it 'extracts the archive into src/' do
      allow(api_client).to receive(:get_plugin_setting_archive).with('42').and_return(archive_tempfile)

      command.call

      expect(File.read(File.join(tmp_root, 'src', 'settings.yml'))).to include('name: pulled')
    end

    it 'overwrites pre-existing read-only files (#83 regression)' do
      FileUtils.mkdir_p(File.join(tmp_root, 'src'))
      stale = File.join(tmp_root, 'src', 'settings.yml')
      File.write(stale, '---')
      File.chmod(0o444, stale)
      allow(api_client).to receive(:get_plugin_setting_archive).with('42').and_return(archive_tempfile)

      expect { command.call }.not_to raise_error
      expect(File.read(stale)).to include('name: pulled')
    end

    it 'raises when no plugin id is supplied or in config' do
      cmd = described_class.new(context:,
                                options: described_class::Options.new(dir: tmp_root,
                                                                      quiet: true, force: true, id: nil))

      expect { cmd.call }.to raise_error(TRMNLP::PluginIdRequired)
    end

    it 'extracts a transform script under whatever filename the archive carries' do
      archive = build_zip_tempfile(
        'settings.yml' => "---\nname: pulled\n",
        'transform.py' => 'def run(input): return input'
      )
      allow(api_client).to receive(:get_plugin_setting_archive).with('42').and_return(archive)

      command.call

      expect(File.read(File.join(tmp_root, 'src', 'transform.py'))).to eq('def run(input): return input')
    ensure
      archive.close
      FileUtils.rm_f(archive.path)
    end
  end

  def build_zip_tempfile(files)
    tf = Tempfile.new(['plugin', '.zip'])
    tf.binmode
    tf.close
    Zip::File.open(tf.path, create: true) do |zip|
      files.each { |name, contents| zip.get_output_stream(name) { |s| s.write(contents) } }
    end
    File.open(tf.path, 'rb')
  end
end
