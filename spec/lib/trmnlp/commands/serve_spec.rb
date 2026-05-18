# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/commands/serve'
require 'trmnlp/app'

RSpec.describe TRMNLP::Commands::Serve do
  subject(:command) do
    described_class.new(context:,
                        options: described_class::Options.new(dir: tmp_root, quiet: true,
                                                              bind: '0.0.0.0', port: 4567))
  end

  let(:tmp_root) { Dir.mktmpdir('trmnlp-serve-') }
  let(:context) { TRMNLP::Context.new(tmp_root) }

  before do
    File.write(File.join(tmp_root, '.trmnlp.yml'), '---')
    allow(TRMNLP::App).to receive(:set)
    allow(TRMNLP::App).to receive(:run!)
  end

  after { FileUtils.rm_rf(tmp_root) }

  describe '#call' do
    it 'wires the context onto the Sinatra app' do
      command.call

      expect(TRMNLP::App).to have_received(:set).with(:context, context)
    end

    it 'wires the bind and port options onto the Sinatra app' do
      command.call

      expect(TRMNLP::App).to have_received(:set).with(:bind, '0.0.0.0')
      expect(TRMNLP::App).to have_received(:set).with(:port, 4567)
    end

    it 'starts the Sinatra app' do
      command.call

      expect(TRMNLP::App).to have_received(:run!)
    end

    context 'outside GitHub Codespaces' do
      before { stub_const('ENV', ENV.to_h.except('CODESPACES')) }

      it 'leaves host authorization untouched' do
        command.call

        expect(TRMNLP::App).not_to have_received(:set).with(:host_authorization, anything)
      end
    end

    context 'inside GitHub Codespaces' do
      before { stub_const('ENV', ENV.to_h.merge('CODESPACES' => 'true')) }

      it 'relaxes host authorization so the forwarded URL is reachable' do
        command.call

        expect(TRMNLP::App).to have_received(:set).with(:host_authorization, hash_including(:allow_if))
      end
    end

    it 'raises when the project is not a trmnlp directory' do
      bad_root = Dir.mktmpdir('trmnlp-serve-bad-')
      cmd = described_class.new(
        context: TRMNLP::Context.new(bad_root),
        options: described_class::Options.new(dir: bad_root, quiet: true, bind: '0.0.0.0', port: 4567)
      )

      expect { cmd.call }.to raise_error(TRMNLP::NotAPlugin)
      expect(TRMNLP::App).not_to have_received(:run!)
    ensure
      FileUtils.remove_entry(bad_root) if bad_root && File.exist?(bad_root)
    end
  end
end
