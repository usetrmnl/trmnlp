# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'tmpdir'
require 'trmnlp/commands/push'

RSpec.describe TRMNLP::Commands::Push do
  subject(:command) do
    described_class.new(context:,
                        options: described_class::Options.new(dir: tmp_root, quiet: true,
                                                              force: true, id: '42'))
  end

  let(:tmp_root) { Dir.mktmpdir('trmnlp-push-') }
  let(:context) { TRMNLP::Context.new(tmp_root) }
  let(:api_client) { instance_double(TRMNLP::APIClient) }
  let(:archive_response) { { 'data' => { 'settings_yaml' => "---\nname: synced\n" } } }
  let(:zip_path) { described_class::ZIP_PATH }

  # What APIClient#get_plugin_setting_archive returns: a rewound zip Tempfile.
  def build_server_archive(entries)
    tempfile = Tempfile.new(['server-archive', '.zip'])
    buffer = Zip::OutputStream.write_buffer do |zip|
      entries.each do |name, content|
        zip.put_next_entry(name)
        zip.print(content)
      end
    end
    buffer.rewind
    tempfile.binmode
    tempfile.write(buffer.read)
    tempfile.rewind
    tempfile
  end

  before do
    File.write(File.join(tmp_root, '.trmnlp.yml'), '---')
    FileUtils.mkdir_p(File.join(tmp_root, 'src'))
    File.write(File.join(tmp_root, 'src', 'settings.yml'), "---\nname: local\n")
    allow(context.config.app).to receive(:logged_in?).and_return(true)
    allow(TRMNLP::APIClient).to receive(:new).and_return(api_client)
    allow(api_client).to receive(:post_plugin_setting_archive).and_return(archive_response)
  end

  after { FileUtils.rm_rf(tmp_root) }

  describe '#call' do
    it 'uploads the archive to the supplied id' do
      command.call

      expect(api_client).to have_received(:post_plugin_setting_archive).with('42', zip_path)
    end

    it 'overwrites the local settings.yml with the response' do
      command.call

      expect(File.read(File.join(tmp_root, 'src', 'settings.yml'))).to include('name: synced')
    end

    it 'removes the upload zip on success' do
      command.call

      expect(File.exist?(zip_path)).to be(false)
    end

    context 'when no id is supplied or configured' do
      subject(:command) do
        described_class.new(context:,
                            options: described_class::Options.new(dir: tmp_root, quiet: true,
                                                                  force: true, id: nil))
      end

      let(:create_response) { { 'data' => { 'id' => 99 } } }

      before { allow(api_client).to receive(:post_plugin_setting).and_return(create_response) }

      it 'creates a new plugin setting on the server' do
        command.call

        expect(api_client).to have_received(:post_plugin_setting).with(name: 'New TRMNLP Plugin', plugin_id: 37)
      end

      it 'uploads the archive to the newly created id' do
        command.call

        expect(api_client).to have_received(:post_plugin_setting_archive).with(99, zip_path)
      end

      it 'rolls back the new plugin setting if upload fails' do
        allow(api_client).to receive(:post_plugin_setting_archive).and_raise(StandardError, 'boom')
        allow(api_client).to receive(:delete_plugin_setting)

        expect { command.call }.to raise_error(StandardError, 'boom')
        expect(api_client).to have_received(:delete_plugin_setting).with(99)
      end
    end

    context 'without --force on an existing plugin' do
      subject(:command) do
        described_class.new(context:,
                            options: described_class::Options.new(dir: tmp_root, quiet: true,
                                                                  force: false, id: '42'))
      end

      before do
        allow(api_client).to receive(:get_plugin_setting_archive)
          .and_return(build_server_archive('settings.yml' => "---\nname: remote\n"))
      end

      it 'aborts when the user declines confirmation' do
        allow(command).to receive(:prompt).and_return('n')

        expect { command.call }.to raise_error(TRMNLP::Aborted)
        expect(api_client).not_to have_received(:post_plugin_setting_archive)
      end

      it 'proceeds when the user confirms with y' do
        allow(command).to receive(:prompt).and_return('y')

        command.call

        expect(api_client).to have_received(:post_plugin_setting_archive).with('42', zip_path)
      end
    end

    it 'raises when not logged in' do
      allow(context.config.app).to receive(:logged_in?).and_return(false)

      expect { command.call }.to raise_error(TRMNLP::NotLoggedIn)
    end

    context 'with a transform script in the project' do
      let(:captured_zip) { {} }

      before do
        allow(api_client).to receive(:post_plugin_setting_archive) do |_id, zip_path|
          Zip::File.open(zip_path) do |zf|
            zf.each { |entry| captured_zip[entry.name] = entry.get_input_stream.read }
          end
          archive_response
        end
      end

      it 'uploads a transform script under its own filename and extension' do
        File.write(File.join(tmp_root, 'src', 'transform.py'), 'def run(input): return input')

        command.call

        expect(captured_zip['transform.py']).to eq('def run(input): return input')
      end
    end

    context 'when the server has a transform but the project has no transform file' do
      subject(:command) do
        described_class.new(context:,
                            options: described_class::Options.new(dir: tmp_root, quiet: true,
                                                                  force: false, id: '42'))
      end

      let(:captured_zip) { {} }
      let(:answer) { 'n' }
      let(:server_entries) { { 'settings.yml' => "---\nname: remote\n", 'transform.js' => 'module.exports = 1' } }
      let(:server_archive) { build_server_archive(server_entries) }

      before do
        allow(command).to receive(:prompt).with(/overwritten/).and_return('y')
        allow(command).to receive(:prompt).with(/Delete it on the server/).and_return(answer)
        allow(api_client).to receive(:get_plugin_setting_archive).and_return(server_archive)
        allow(api_client).to receive(:post_plugin_setting_archive) do |_id, path|
          Zip::File.open(path) do |zip_file|
            zip_file.each { |entry| captured_zip[entry.name] = entry.get_input_stream.read }
          end
          archive_response
        end
      end

      context 'when the user confirms removal' do
        let(:answer) { 'y' }

        it 'pushes settings.yml with the removal request' do
          command.call

          expect(YAML.safe_load(captured_zip['settings.yml'])).to include('serverless_language' => 'none')
        end
      end

      context 'when the user declines removal' do
        it 'pushes settings.yml untouched' do
          command.call

          expect(captured_zip['settings.yml']).to eq("---\nname: local\n")
        end
      end

      context 'when the project still has a transform file' do
        before { File.write(File.join(tmp_root, 'src', 'transform.py'), 'code') }

        it 'asks no removal question' do
          command.call

          expect(api_client).not_to have_received(:get_plugin_setting_archive)
        end
      end

      context 'when the server archive has no transform entry' do
        let(:server_entries) { { 'settings.yml' => "---\nname: remote\n" } }

        it 'asks no removal question' do
          command.call

          expect(command).not_to have_received(:prompt).with(/Delete it on the server/)
        end
      end

      context 'when the server archive cannot be downloaded' do
        before { allow(api_client).to receive(:get_plugin_setting_archive).and_raise(TRMNLP::Error, 'boom') }

        it 'still pushes' do
          command.call

          expect(api_client).to have_received(:post_plugin_setting_archive)
        end
      end
    end

    context 'with --force when the server has a transform but the project has no transform file' do
      before { allow(api_client).to receive(:get_plugin_setting_archive) }

      it 'skips the removal flow entirely' do
        command.call

        expect(api_client).not_to have_received(:get_plugin_setting_archive)
      end
    end
  end
end
