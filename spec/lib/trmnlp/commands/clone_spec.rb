# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/commands/clone'

RSpec.describe TRMNLP::Commands::Clone do
  subject(:command) do
    described_class.new(context:, options: described_class::Options.new(dir: tmp_root, quiet: true, skip_git: false))
  end

  let(:tmp_root) { Dir.mktmpdir('trmnlp-clone-') }
  let(:context) { TRMNLP::Context.new(tmp_root) }

  before do
    File.write(File.join(tmp_root, '.trmnlp.yml'), '---')
    allow(context.config.app).to receive(:logged_in?).and_return(true)
    allow(TRMNLP::Commands::Init).to receive(:run)
    allow(TRMNLP::Commands::Pull).to receive(:run)
  end

  after { FileUtils.rm_rf(tmp_root) }

  describe '#call' do
    it 'scaffolds the project via Init' do
      command.call('my-plugin', '42')

      expect(TRMNLP::Commands::Init).to have_received(:run)
        .with({ dir: tmp_root, skip_liquid: true, quiet: true, skip_git: false }, 'my-plugin')
    end

    it 'pulls the plugin settings into the new directory' do
      command.call('my-plugin', '42')

      expected_path = File.join(tmp_root, 'my-plugin')
      expect(TRMNLP::Commands::Pull).to have_received(:run).with({ dir: expected_path, force: true, id: '42' })
    end

    it 'raises when the destination directory already exists' do
      FileUtils.mkdir_p(File.join(tmp_root, 'existing'))

      expect { command.call('existing', '42') }.to raise_error(TRMNLP::DirectoryExists)
      expect(TRMNLP::Commands::Init).not_to have_received(:run)
    end

    it 'raises when not logged in' do
      allow(context.config.app).to receive(:logged_in?).and_return(false)

      expect { command.call('my-plugin', '42') }.to raise_error(TRMNLP::NotLoggedIn)
    end

    it 'forwards skip_git to Init' do
      cmd = described_class.new(context:,
                                options: described_class::Options.new(dir: tmp_root, quiet: true, skip_git: true))
      cmd.call('skipped', '99')

      expect(TRMNLP::Commands::Init).to have_received(:run)
        .with({ dir: tmp_root, skip_liquid: true, quiet: true, skip_git: true }, 'skipped')
    end
  end
end
