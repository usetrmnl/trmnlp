# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/commands/init'

RSpec.describe TRMNLP::Commands::Init do
  subject(:command) do
    described_class.new(context:, options: described_class::Options.new(dir: tmp_root, quiet: true, skip_liquid: false))
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
                                                                      quiet: true, skip_liquid: true))
      cmd.call('no-liquid')

      project = File.join(tmp_root, 'no-liquid')
      expect(File).to exist(File.join(project, 'src', 'settings.yml'))
      expect(File).not_to exist(File.join(project, 'src', 'full.liquid'))
    end
  end
end
