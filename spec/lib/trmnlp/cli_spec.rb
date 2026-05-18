# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/cli'

RSpec.describe TRMNLP::CLI do
  describe '#lint' do
    let(:tmp_root) { Dir.mktmpdir('trmnlp-cli-') }
    let(:run_lint) { -> { described_class.start(['lint', '--dir', tmp_root, '--quiet']) } }

    before do
      File.write(File.join(tmp_root, '.trmnlp.yml'), '{}')
      FileUtils.mkdir_p(File.join(tmp_root, 'src'))
      File.write(File.join(tmp_root, 'src', 'shared.liquid'), '<p>Some real content here</p>')
    end

    after { FileUtils.rm_rf(tmp_root) }

    context 'when the plugin has lint issues' do
      before do
        File.write(
          File.join(tmp_root, 'src', 'settings.yml'),
          { 'custom_fields' => [{ 'keyname' => 'broken' }] }.to_yaml
        )
      end

      it 'exits non-zero so CI can gate on it' do
        expect(&run_lint).to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end

    context 'when the plugin passes all checks' do
      it 'does not exit non-zero' do
        expect(&run_lint).not_to raise_error
      end
    end
  end
end
