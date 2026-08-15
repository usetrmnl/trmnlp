# frozen_string_literal: true

require 'spec_helper'
require 'fileutils'
require 'tmpdir'
require 'trmnlp/transform_backend/which'

RSpec.describe TRMNLP::TransformBackend::Which do
  subject(:which) { described_class }

  let(:bin) { Dir.mktmpdir('trmnlp-which-') }
  # Joined with the platform separator so the PATHEXT split matches Windows
  # (`;`) and POSIX (`:`) without the spec caring which it runs on.
  let(:windows_pathext) { ['.COM', '.BAT'].join(File::PATH_SEPARATOR) }

  after { FileUtils.remove_entry(bin) }

  describe '.locate' do
    it 'answers the full path of an executable found on PATH' do
      executable = File.join(bin, 'widget')
      File.write(executable, '')
      File.chmod(0o755, executable)

      expect(which.locate('widget', path: bin)).to eq(executable)
    end

    it 'answers nil when the command is absent from PATH' do
      expect(which.locate('ghost', path: bin)).to be(nil)
    end

    it 'ignores a matching file that is not executable' do
      File.write(File.join(bin, 'widget'), '')

      expect(which.locate('widget', path: bin)).to be(nil)
    end

    it 'appends a PATHEXT suffix when locating a Windows executable' do
      executable = File.join(bin, 'widget.BAT')
      File.write(executable, '')
      File.chmod(0o755, executable)

      expect(which.locate('widget', path: bin, pathext: windows_pathext)).to eq(executable)
    end
  end

  describe '.resolve' do
    it 'answers the first candidate present on PATH' do
      %w[python py].each do |name|
        File.write(File.join(bin, name), '')
        File.chmod(0o755, File.join(bin, name))
      end

      expect(which.resolve(%w[python3 python py], path: bin)).to eq('python')
    end

    it 'answers the highest-priority candidate when several are present' do
      %w[python3 python].each do |name|
        File.write(File.join(bin, name), '')
        File.chmod(0o755, File.join(bin, name))
      end

      expect(which.resolve(%w[python3 python py], path: bin)).to eq('python3')
    end

    it 'answers the first candidate name when none resolve, preserving the ENOENT path' do
      expect(which.resolve(%w[python3 python py], path: bin)).to eq('python3')
    end
  end
end
