# frozen_string_literal: true

require 'spec_helper'
require 'tempfile'
require 'tmpdir'
require 'trmnlp/commands/build'

RSpec.describe TRMNLP::Commands::Build do
  subject(:command) { described_class.new(context:, options:, reporter:) }

  let(:tmp_root) { Dir.mktmpdir('trmnlp-build-') }
  let(:context) { TRMNLP::Context.new(tmp_root) }
  let(:reporter) { TRMNLP::Reporter.new(quiet: true) }
  let(:options) do
    described_class::Options.new(dir: tmp_root, quiet: true, png: false,
                                 width: nil, height: nil, color_depth: nil)
  end

  before do
    File.write(File.join(tmp_root, '.trmnlp.yml'), '---')
    allow(context.poller).to receive(:poll_data)
    allow(context.renderer).to receive(:render_full_page) { |view| "<html>#{view}</html>" }
  end

  after { FileUtils.rm_rf(tmp_root) }

  def write_settings(settings)
    FileUtils.mkdir_p(File.join(tmp_root, 'src'))
    File.write(File.join(tmp_root, 'src', 'settings.yml'), settings.to_yaml)
    context.config.plugin.reload!
  end

  describe '#call' do
    it 'creates the build dir' do
      command.call

      expect(File).to exist(File.join(tmp_root, '_build'))
    end

    it 'writes an HTML file for every view' do
      command.call

      written = Dir[File.join(tmp_root, '_build', '*.html')].map { |path| File.basename(path, '.html') }
      expect(written).to contain_exactly(*TRMNLP::Screen.names)
    end

    it 'renders each view through the context' do
      command.call

      expect(File.read(File.join(tmp_root, '_build', 'full.html'))).to eq('<html>full</html>')
    end

    it 'warns about malformed custom fields declared in settings.yml' do
      write_settings('custom_fields' => [{ 'keyname' => 'broken' }])

      command.call

      expect(reporter.messages).to include(a_string_matching(/custom_fields/))
    end

    it 'warns when settings.yml pins a framework version the manifest has not heard of' do
      write_settings('framework_version' => '99.99.99')

      command.call

      expect(reporter.messages).to include(a_string_matching(/framework_version 99\.99\.99/))
    end

    it 'stays quiet about a framework version the manifest lists' do
      write_settings('framework_version' => TRMNLP::FrameworkVersion.version_numbers.last)

      command.call

      expect(reporter.messages).not_to include(a_string_matching(/framework_version/))
    end

    it 'raises when the project is not a trmnlp directory' do
      bad_root = Dir.mktmpdir('trmnlp-build-bad-')
      bad_options = described_class::Options.new(dir: bad_root, quiet: true, png: false,
                                                 width: nil, height: nil, color_depth: nil)
      cmd = described_class.new(context: TRMNLP::Context.new(bad_root), options: bad_options)

      expect { cmd.call }.to raise_error(TRMNLP::NotAPlugin)
    ensure
      FileUtils.rm_rf(bad_root)
    end

    context 'with --png (#92)' do
      let(:options) do
        described_class::Options.new(dir: tmp_root, quiet: true, png: true,
                                     width: nil, height: nil, color_depth: nil)
      end
      let(:screen_generator) { instance_double(TRMNLP::ScreenGenerator) }

      before do
        allow(TRMNLP::ScreenGenerator).to receive(:new).and_return(screen_generator)
        allow(screen_generator).to receive(:process) do
          file = Tempfile.new(['screenshot', '.png'])
          file.write('fake-png')
          file.close
          file
        end
      end

      it 'writes a PNG for every view' do
        command.call

        written = Dir[File.join(tmp_root, '_build', '*.png')].map { |path| File.basename(path, '.png') }
        expect(written).to contain_exactly(*TRMNLP::Screen.names)
      end

      it 'still writes the HTML files' do
        command.call

        written = Dir[File.join(tmp_root, '_build', '*.html')].map { |path| File.basename(path, '.html') }
        expect(written).to contain_exactly(*TRMNLP::Screen.names)
      end

      it 'screenshots the rendered markup for each view' do
        command.call

        expect(TRMNLP::ScreenGenerator).to have_received(:new).with('<html>full</html>', anything)
      end

      it 'passes the width, height and colour depth to the screen generator' do
        sized = described_class::Options.new(dir: tmp_root, quiet: true, png: true,
                                             width: 400, height: 200, color_depth: 2)
        described_class.new(context:, options: sized, reporter:).call

        expect(TRMNLP::ScreenGenerator).to have_received(:new).with(
          '<html>full</html>', hash_including(width: 400, height: 200, color_depth: 2)
        )
      end
    end
  end
end
