# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/cli'

RSpec.describe TRMNLP::CLI do
  # Every command may consult the update-check cache, so keep it out of the
  # real cache directory and empty for each example.
  around do |example|
    Dir.mktmpdir('trmnlp-cache-') do |cache_home|
      previous = ENV.fetch('XDG_CACHE_HOME', nil)
      ENV['XDG_CACHE_HOME'] = cache_home
      example.run
    ensure
      ENV['XDG_CACHE_HOME'] = previous
    end
  end

  describe '.default_bind' do
    before { allow(File).to receive(:exist?).and_return(false) }

    context 'when running inside Docker' do
      before { allow(File).to receive(:exist?).with('/.dockerenv').and_return(true) }

      it 'binds to all interfaces' do
        expect(described_class.default_bind).to eq('0.0.0.0')
      end
    end

    context 'when running inside Podman' do
      before { allow(File).to receive(:exist?).with('/run/.containerenv').and_return(true) }

      it 'binds to all interfaces' do
        expect(described_class.default_bind).to eq('0.0.0.0')
      end
    end

    context 'when running outside a container' do
      it 'binds to localhost' do
        expect(described_class.default_bind).to eq('127.0.0.1')
      end
    end
  end

  describe 'update notices' do
    let(:tmp_root) { Dir.mktmpdir('trmnlp-cli-') }
    let(:endpoint) { 'https://rubygems.org/api/v1/gems/trmnl_preview.json' }

    before { stub_request(:get, endpoint).to_return(body: { version: '99.0.0' }.to_json) }

    it 'checks RubyGems for any command' do
      capture_stderr { capture_stdout { described_class.start(['init', 'plugin', '--dir', tmp_root, '--skip-git']) } }

      expect(WebMock).to have_requested(:get, endpoint).once
    end

    it 'reports the update before the command runs, so a server does not hide it' do
      output = capture_stderr do
        capture_stdout { described_class.start(['init', 'plugin', '--dir', tmp_root, '--skip-git']) }
      end

      expect(output).to start_with('trmnl_preview 99.0.0 is available')
    end

    it 'does not check for help' do
      capture_stdout { described_class.start(['help']) }

      expect(WebMock).not_to have_requested(:get, endpoint)
    end

    it 'asks RubyGems at most once a day across commands' do
      capture_stderr { capture_stdout { described_class.start(['init', 'plugin', '--dir', tmp_root, '--skip-git']) } }
      capture_stderr { capture_stdout { described_class.start(['init', 'other', '--dir', tmp_root, '--skip-git']) } }

      expect(WebMock).to have_requested(:get, endpoint).once
    end

    it 'skips the check when TRMNLP_NO_UPDATE_NOTIFIER is set' do
      allow(ENV).to receive(:[]).and_call_original
      allow(ENV).to receive(:[]).with('TRMNLP_NO_UPDATE_NOTIFIER').and_return('1')
      capture_stdout { described_class.start(['init', 'plugin', '--dir', tmp_root, '--skip-git', '--quiet']) }

      expect(WebMock).not_to have_requested(:get, endpoint)
    end
  end

  describe '#version' do
    let(:endpoint) { 'https://rubygems.org/api/v1/gems/trmnl_preview.json' }

    before { stub_request(:get, endpoint).to_return(body: { version: '99.0.0' }.to_json) }

    it 'prints the installed version to stdout' do
      output = nil
      capture_stderr { output = capture_stdout { described_class.start(['version']) } }

      expect(output).to eq("#{TRMNLP::VERSION}\n")
    end

    it 'reports a newer release' do
      expect { capture_stdout { described_class.start(['version']) } }
        .to output(/trmnl_preview 99\.0\.0 is available/).to_stderr
    end

    it 'asks RubyGems even when the cache is fresh' do
      capture_stderr { capture_stdout { described_class.start(['version']) } }
      capture_stderr { capture_stdout { described_class.start(['version']) } }

      expect(WebMock).to have_requested(:get, endpoint).twice
    end

    it 'skips the check in quiet mode' do
      capture_stdout { described_class.start(['version', '--quiet']) }

      expect(WebMock).not_to have_requested(:get, endpoint)
    end
  end

  describe '#lint' do
    let(:tmp_root) { Dir.mktmpdir('trmnlp-cli-') }
    let(:endpoint) { 'https://rubygems.org/api/v1/gems/trmnl_preview.json' }
    let(:run_lint) { -> { described_class.start(['lint', '--dir', tmp_root, '--quiet']) } }

    before do
      stub_request(:get, endpoint).to_return(body: { version: TRMNLP::VERSION }.to_json)
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

      it 'keeps a nonzero exit status with JSON output' do
        expect do
          described_class.start(['lint', '--dir', tmp_root, '--quiet', '--format', 'json'])
        end.to raise_error(SystemExit) { |error| expect(error.status).to eq(1) }
      end
    end

    context 'when a newer release is available' do
      before { stub_request(:get, endpoint).to_return(body: { version: '99.0.0' }.to_json) }

      it 'checks RubyGems during an ordinary lint run' do
        lint_status

        expect(WebMock).to have_requested(:get, endpoint).once
      end

      it 'reports the update on stderr' do
        expect do
          capture_stdout { described_class.start(['lint', '--dir', tmp_root]) }
        end.to output(/trmnl_preview 99\.0\.0 is available/).to_stderr
      end

      it 'preserves valid JSON output' do
        output = capture_stdout do
          capture_stderr { described_class.start(['lint', '--dir', tmp_root, '--format', 'json']) }
        end

        expect(JSON.parse(output)).to eq('version' => 1, 'passed' => true, 'issues' => [])
      end

      it 'does not fail clean lint because an update is available' do
        expect(lint_status).to eq(0)
      end

      it 'preserves failing lint status when an update is available' do
        File.write(File.join(tmp_root, 'src', 'settings.yml'), { 'description' => 'x' * 36 }.to_yaml)

        expect(lint_status).to eq(1)
      end

      it 'checks for updates even when lint has findings' do
        File.write(File.join(tmp_root, 'src', 'settings.yml'), { 'description' => 'x' * 36 }.to_yaml)
        lint_status

        expect(WebMock).to have_requested(:get, endpoint).once
      end

      it 'skips the network check in quiet mode' do
        capture_stdout(&run_lint)

        expect(WebMock).not_to have_requested(:get, endpoint)
      end

      it 'does not emit notices in quiet mode' do
        expect { capture_stdout(&run_lint) }.not_to output.to_stderr
      end
    end

    context 'when RubyGems is unavailable' do
      before { stub_request(:get, endpoint).to_timeout }

      it 'keeps clean lint successful' do
        expect(lint_status).to eq(0)
      end

      it 'keeps failing lint unsuccessful' do
        File.write(File.join(tmp_root, 'src', 'settings.yml'), { 'description' => 'x' * 36 }.to_yaml)

        expect(lint_status).to eq(1)
      end

      it 'does not print an update-check error' do
        expect do
          capture_stdout { described_class.start(['lint', '--dir', tmp_root]) }
        end.not_to output.to_stderr
      end
    end

    context 'when the plugin passes all checks' do
      it 'does not exit non-zero' do
        expect(&run_lint).not_to raise_error
      end

      it 'writes parseable JSON without terminal decorations' do
        output = capture_stdout do
          described_class.start(['lint', '--dir', tmp_root, '--format', 'json'])
        end
        expect(JSON.parse(output)).to eq('version' => 1, 'passed' => true, 'issues' => [])
      end
    end
  end

  def lint_status
    capture_stdout { capture_stderr { described_class.start(['lint', '--dir', tmp_root]) } }
    0
  rescue SystemExit => e
    e.status
  end

  def capture_stderr
    stream = StringIO.new
    original = $stderr
    $stderr = stream
    yield
    stream.string
  ensure
    $stderr = original
  end

  def capture_stdout
    stream = StringIO.new
    original = $stdout
    $stdout = stream
    yield
    stream.string
  ensure
    $stdout = original
  end
end
