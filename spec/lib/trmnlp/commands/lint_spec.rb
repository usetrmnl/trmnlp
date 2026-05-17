# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/commands/lint'

RSpec.describe TRMNLP::Commands::Lint do
  subject(:command) do
    described_class.new(context:, options: described_class::Options.new(dir: tmp_root, quiet: true), reporter:)
  end

  let(:tmp_root) { Dir.mktmpdir('trmnlp-lint-') }
  let(:context) { TRMNLP::Context.new(tmp_root) }
  let(:reporter) { TRMNLP::Reporter.new(quiet: true) }

  before do
    File.write(File.join(tmp_root, '.trmnlp.yml'), '{}')
    FileUtils.mkdir_p(File.join(tmp_root, 'src'))
    File.write(File.join(tmp_root, 'src', 'shared.liquid'), '<p>Some real content here</p>')
  end

  after { FileUtils.rm_rf(tmp_root) }

  describe '#call' do
    context 'with a clean plugin' do
      it 'reports that all checks passed' do
        command.call

        expect(reporter.messages).to include(a_string_matching(/All checks passed/))
      end
    end

    context 'with a malformed custom field in settings.yml' do
      before do
        File.write(
          File.join(tmp_root, 'src', 'settings.yml'),
          { 'custom_fields' => [{ 'keyname' => 'broken' }] }.to_yaml
        )
      end

      it 'flags the form-field issue' do
        command.call

        expect(reporter.messages).to include(a_string_matching(/custom_fields/))
      end

      it 'returns false' do
        expect(command.call).to be(false)
      end
    end

    it 'raises when the project is not a trmnlp directory' do
      bad_root = Dir.mktmpdir('trmnlp-lint-bad-')
      cmd = described_class.new(
        context: TRMNLP::Context.new(bad_root),
        options: described_class::Options.new(dir: bad_root, quiet: true)
      )

      expect { cmd.call }.to raise_error(TRMNLP::NotAPlugin)
    ensure
      FileUtils.remove_entry(bad_root) if bad_root && File.exist?(bad_root)
    end
  end
end
