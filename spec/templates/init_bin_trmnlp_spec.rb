# frozen_string_literal: true

require 'spec_helper'
require 'pty'
require 'timeout'
require 'tmpdir'

# Runs the script `trmnlp init` puts in a plugin, with stand-ins for docker and the gem on a PATH that
# holds nothing else, so the examples read the exact `docker` commands it would run.
RSpec.describe 'templates/init/bin/trmnlp' do
  let(:script) { File.expand_path('../../templates/init/bin/trmnlp', __dir__) }
  let(:tmp) { File.realpath(Dir.mktmpdir('trmnlp-bin-')) }
  let(:path) { File.join(tmp, 'path') }
  let(:config_dir) { File.join(tmp, 'config') }
  let(:plugin_dir) { File.join(tmp, 'plugin') }
  let(:docker_log) { File.join(tmp, 'docker.log') }
  let(:bash_starts) { File.join(tmp, 'bash-starts') }
  let(:env) do
    { 'PATH' => path, 'HOME' => tmp, 'XDG_CONFIG_HOME' => config_dir, 'XDG_CACHE_HOME' => nil,
      'DOCKER_LOG' => docker_log, 'BASH_STARTS' => bash_starts,
      'CI' => nil, 'TRMNL_API_KEY' => nil }
  end
  let(:id) { "#{Process.uid}:#{Process.gid}" }

  before do
    FileUtils.mkdir_p([path, plugin_dir])
    %w[env find id mkdir touch].each { |tool| File.symlink(which(tool), File.join(path, tool)) }
    # The script finds bash on this PATH. A script that runs itself would start processes until the
    # machine is out of memory, so this bash counts its starts and gives up after 20.
    stand_in('bash', <<~SH)
      read -r starts < "$BASH_STARTS"
      echo "$((starts + 1))" > "$BASH_STARTS"
      [ "$starts" -ge 20 ] && { echo "bin/trmnlp ran itself over and over"; exit 97; }
      exec "#{which('bash')}" "$@"
    SH
    File.write(bash_starts, "0\n")
    stand_in('uname', 'echo "${FAKE_UNAME:-Linux}"')
    stand_in('docker', <<~SH)
      echo "$*" >> "$DOCKER_LOG"
      [ "$1" = pull ] && exit "${FAKE_PULL_STATUS:-0}"
      [ "$1" = info ] && echo "[name=seccomp,profile=builtin ${FAKE_DOCKER_SECURITY:-}]"
      exit 0
    SH
  end

  after { FileUtils.rm_rf(tmp) }

  def which(tool)
    ENV.fetch('PATH').split(':').map { |dir| File.join(dir, tool) }.find { |file| File.executable?(file) }
  end

  def stand_in(name, body)
    File.write(File.join(path, name), "#!#{which('bash')}\n#{body}")
    File.chmod(0o755, File.join(path, name))
  end

  # Runs the script in its own process group and kills the group when it takes too long.
  def run(*, dir: plugin_dir, command: script, **extra)
    reader, writer = IO.pipe
    pid = Process.spawn(env.merge(extra.transform_keys(&:to_s)), command, *,
                        chdir: dir, in: File::NULL, out: writer, err: writer, pgroup: true)
    writer.close
    status = Timeout.timeout(20) { Process.wait2(pid).last }
    [reader.read, status]
  rescue Timeout::Error
    Process.kill('KILL', -pid)
    raise
  end

  def docker_calls = File.exist?(docker_log) ? File.readlines(docker_log, chomp: true) : []
  def docker_run = docker_calls.grep(/\Arun /).last
  def docker_pulls = docker_calls.grep(/\Apull /)

  context 'with the gem installed' do
    before { stand_in('trmnlp', 'echo "gem $*"') }

    it 'runs the gem' do
      expect(run('lint').first).to eq("gem lint\n")
    end
  end

  context 'when saved as trmnlp on the PATH' do
    before { FileUtils.cp(script, File.join(path, 'trmnlp')) }

    it 'runs the Docker image and not itself over and over' do
      run('lint', command: File.join(path, 'trmnlp'))
      expect(docker_run).to end_with(' trmnl/trmnlp lint')
    end
  end

  context 'with neither the gem nor Docker' do
    before { File.delete(File.join(path, 'docker')) }

    it 'says how to install them' do
      expect(run('lint').first).to include('gem install trmnl_preview')
    end

    it 'fails' do
      expect(run('lint').last).not_to be_success
    end
  end

  it 'passes the command and its arguments to the image' do
    run('test', 'tests/a_spec.rb', '-e', 'dark mode')
    expect(docker_run).to end_with(' trmnl/trmnlp test tests/a_spec.rb -e dark mode')
  end

  it 'asks for no terminal when it has none, as on CI' do
    run('lint')
    expect(docker_run).not_to include('--tty')
  end

  it 'asks for a terminal when it has one' do
    PTY.spawn(env, script, 'lint', chdir: plugin_dir) { |_out, _in, pid| Timeout.timeout(20) { Process.wait(pid) } }
    expect(docker_run).to include('--tty')
  end

  it 'publishes the port for serve' do
    run('serve')
    expect(docker_run).to include('--publish 4567:4567')
  end

  ['--port 5000', '-p 5000', '--port=5000'].each do |option|
    it "publishes the port serve listens on with #{option}" do
      run('serve', *option.split)
      expect(docker_run).to include('--publish 5000:5000')
    end
  end

  it 'publishes no port for other commands, so they run next to serve' do
    run('lint')
    expect(docker_run).not_to include('--publish')
  end

  it 'passes CI on, which makes a missing snapshot a failure' do
    run('test', CI: 'true')
    expect(docker_run).to include('--env CI')
  end

  describe 'who owns the files trmnlp writes' do
    it 'runs as the calling user on Linux' do
      run('test')
      expect(docker_run).to include("--user #{id}")
    end

    # Docker makes the folders above a mount as root. Firefox then cannot write its home and
    # `trmnlp test` hangs without a word, so both folders are made for the user first.
    it 'gives that user a home, a .config and a .cache it can write' do
      run('test')
      expect(docker_run).to include("--tmpfs /tmp/home:exec,uid=#{Process.uid},gid=#{Process.gid} " \
                                    "--tmpfs /tmp/home/.config:uid=#{Process.uid},gid=#{Process.gid} " \
                                    "--tmpfs /tmp/home/.cache:exec,uid=#{Process.uid},gid=#{Process.gid}")
    end

    it 'keeps what trmnlp caches between runs, as the OAuth tokens of a plugin' do
      run('serve')
      expect(docker_run).to include("--volume #{tmp}/.cache/trmnl:/tmp/home/.cache/trmnl")
    end

    it 'keeps the cache where XDG_CACHE_HOME says' do
      run('serve', XDG_CACHE_HOME: File.join(tmp, 'cache'))
      expect(docker_run).to include("--volume #{tmp}/cache/trmnl:/tmp/home/.cache/trmnl")
    end

    it 'mounts the API key where that user looks for it' do
      run('test')
      expect(docker_run).to include("--volume #{config_dir}/trmnlp:/tmp/home/.config/trmnlp")
    end

    it 'stays root under rootless Docker, where root already is the calling user' do
      run('test', FAKE_DOCKER_SECURITY: 'name=rootless')
      expect(docker_run).not_to include('--user')
    end

    it 'stays root on macOS, where Docker Desktop already hands the files to the user' do
      run('test', FAKE_UNAME: 'Darwin')
      expect(docker_run).to include("--volume #{config_dir}/trmnlp:/root/.config/trmnlp")
    end
  end

  describe 'keeping the image current' do
    let(:pulled_at) { File.join(tmp, '.cache', 'trmnl', 'image_pulled') }

    it 'pulls the image on the first run' do
      run('lint')
      expect(docker_pulls).to eq(['pull --quiet trmnl/trmnlp'])
    end

    it 'pulls at most once a day' do
      2.times { run('lint') }
      expect(docker_pulls.size).to eq(1)
    end

    it 'pulls again after a day' do
      run('lint')
      File.utime(Time.now - (25 * 60 * 60), Time.now - (25 * 60 * 60), pulled_at)
      run('lint')
      expect(docker_pulls.size).to eq(2)
    end

    it 'runs the image it has when the pull fails, as with no network' do
      run('lint', FAKE_PULL_STATUS: '1')
      expect(docker_run).to end_with(' trmnl/trmnlp lint')
    end
  end

  it 'mounts the folder it is run in' do
    run('lint')
    expect(docker_run).to include("--volume #{plugin_dir}:/plugin ")
  end
end
