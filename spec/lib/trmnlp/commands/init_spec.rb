# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/commands/init'

RSpec.describe TRMNLP::Commands::Init do
  subject(:command) do
    described_class.new(context:,
                        options: described_class::Options.new(dir: tmp_root, quiet: true,
                                                              skip_liquid: false, skip_git: false))
  end

  let(:tmp_root) { Dir.mktmpdir('trmnlp-init-') }
  let(:context) { TRMNLP::Context.new(tmp_root) }

  after { FileUtils.rm_rf(tmp_root) }

  describe '#call' do
    it 'creates the project directory and copies the template tree' do
      command.call('demo')

      project = File.join(tmp_root, 'demo')
      expect(File).to exist(File.join(project, '.trmnlp.yml'))
      expect(File).to exist(File.join(project, 'bin', 'trmnlp'))
      expect(File).to exist(File.join(project, 'src', 'settings.yml'))
      expect(File).to exist(File.join(project, 'src', 'full.liquid'))
    end

    it 'omits liquid files when skip_liquid is true' do
      cmd = described_class.new(context:,
                                options: described_class::Options.new(dir: tmp_root,
                                                                      quiet: true, skip_liquid: true,
                                                                      skip_git: false))
      cmd.call('no-liquid')

      project = File.join(tmp_root, 'no-liquid')
      expect(File).to exist(File.join(project, 'src', 'settings.yml'))
      expect(File).not_to exist(File.join(project, 'src', 'full.liquid'))
    end

    it 'scaffolds the GitHub Actions workflow' do
      command.call('demo')

      expect(File).to exist(File.join(tmp_root, 'demo', '.github', 'workflows', 'trmnl.yml'))
    end

    it 'scaffolds a gitignore' do
      command.call('demo')

      expect(File).to exist(File.join(tmp_root, 'demo', '.gitignore'))
    end

    it 'initializes a git repository' do
      command.call('demo')

      expect(File).to be_directory(File.join(tmp_root, 'demo', '.git'))
    end

    it 'initializes the git repository on the main branch' do
      command.call('demo')

      head = File.read(File.join(tmp_root, 'demo', '.git', 'HEAD')).strip
      expect(head).to eq('ref: refs/heads/main')
    end

    it 'skips git init when skip_git is true' do
      cmd = described_class.new(context:,
                                options: described_class::Options.new(dir: tmp_root,
                                                                      quiet: true, skip_liquid: false,
                                                                      skip_git: true))
      cmd.call('no-git')

      expect(File).not_to be_directory(File.join(tmp_root, 'no-git', '.git'))
    end

    context 'when the template source is read-only (#83)' do
      let(:templates_dir) { Pathname.new(Dir.mktmpdir('trmnlp-templates-')) }
      let(:read_only_file) { templates_dir.join('init', 'src', 'settings.yml') }
      let(:read_only_executable) { templates_dir.join('init', 'bin', 'trmnlp') }

      before do
        read_only_file.dirname.mkpath
        read_only_file.write("---\nname: demo\n")
        read_only_file.chmod(0o444)

        read_only_executable.dirname.mkpath
        read_only_executable.write("#!/usr/bin/env ruby\n")
        read_only_executable.chmod(0o555)

        allow(context.paths).to receive(:templates_dir).and_return(templates_dir)
      end

      after { FileUtils.rm_rf(templates_dir) }

      it 'makes copied files owner-writable' do
        command.call('demo')

        expect(Pathname.new(tmp_root).join('demo/src/settings.yml').stat.mode & 0o200).to eq(0o200)
      end

      it 'preserves the executable bit on copied files' do
        command.call('demo')

        expect(Pathname.new(tmp_root).join('demo/bin/trmnlp').stat.mode & 0o100).to eq(0o100)
      end
    end
  end
end
