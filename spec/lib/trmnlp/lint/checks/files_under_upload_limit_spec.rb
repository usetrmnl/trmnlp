# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/config'
require 'trmnlp/paths'
require 'trmnlp/lint/source'
require 'trmnlp/lint/checks/files_under_upload_limit'

RSpec.describe TRMNLP::Lint::Checks::FilesUnderUploadLimit do
  subject(:check) { described_class.new(source) }

  let(:root) { Pathname(Dir.mktmpdir) }
  let(:paths) { TRMNLP::Paths.new(root) }
  let(:source) { TRMNLP::Lint::Source.new(config: nil, paths:) }

  before do
    root.join('src').mkpath
    root.join('src/settings.yml').write("name: Test\n")
  end

  after { FileUtils.remove_entry(root) }

  describe '#issues' do
    context 'with a settings.yml over 100 KB' do
      before { root.join('src/settings.yml').write("static_data: '#{'x' * 102_400}'\n") }

      it 'reports the file and its size' do
        expect(check.issues).to eq(
          [{ message: 'src/settings.yml is 102416 bytes; TRMNL refuses to import a file over 100 KB.' }]
        )
      end
    end

    context 'with a view and a transform over 100 KB' do
      before do
        root.join('src/full.liquid').write('x' * 102_401)
        root.join('src/transform.js').write('x' * 102_401)
      end

      it 'reports each one' do
        expect(check.issues.map { it[:message][/\A\S+/] }).to eq(%w[src/full.liquid src/transform.js])
      end
    end

    context 'with a file of exactly 100 KB' do
      before { root.join('src/full.liquid').write('x' * 102_400) }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end

    context 'with a large file TRMNL does not read' do
      before { root.join('src/notes.md').write('x' * 102_401) }

      it 'passes' do
        expect(check.issues).to be_empty
      end
    end
  end
end
