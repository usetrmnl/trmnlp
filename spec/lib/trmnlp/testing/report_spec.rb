# frozen_string_literal: true

require 'json'
require 'spec_helper'
require 'tmpdir'
require 'trmnlp/testing/report'

RSpec.describe TRMNLP::Testing::Report do
  subject(:report) { described_class.new(dir) }

  let(:dir) { Dir.mktmpdir('trmnlp-report-') }
  let(:png) { File.join(Dir.mktmpdir, 'screen.png').tap { File.binwrite(it, 'png') } }
  let(:device) { Struct.new(:name, :width, :height).new('og_png', 800, 480) }
  let(:screen) do
    double('screen', png_path: png, device:, view: 'full', problems: ['failed to load https://x.test/a.png'],
                     evaluate: [{ 'tag' => 'span', 'x' => 1, 'y' => 2, 'w' => 30, 'h' => 10 }])
  end
  let(:run) do
    request = { method: 'GET', url: 'https://api.test/a', status: 200, via: :transform, aborted: false }
    double('run', duration_ms: 120, max_memory_mb: 40.5, error: nil, requests: [request])
  end
  let(:passed) { notification('shows the weather', :passed) }
  let(:failed) { notification('keeps its state', :failed, message: 'expected 5, got 4') }

  def notification(description, status, message: nil)
    example = double('example', id: "./tests/x_spec.rb[1:#{description.size}]", full_description: description,
                                location: './tests/x_spec.rb:3', execution_result: double(status:),
                                exception: message && RuntimeError.new(message))
    double('notification', example:)
  end

  def example_running(notification, &)
    allow(RSpec).to receive(:current_example).and_return(notification.example)
    yield
  end

  before { stub_const('ENV', ENV.to_h.except('GITHUB_STEP_SUMMARY')) }
  after { FileUtils.remove_entry(dir) }

  context 'with a screen and a transform run recorded' do
    before do
      example_running(passed) { report.record_screen(screen) }
      example_running(failed) { report.record_run(run) }
      report.example_passed(passed)
      report.example_failed(failed)
      report.close(nil)
    end

    let(:json) { JSON.parse(File.read(File.join(dir, 'report.json'))) }

    it 'writes every example with its status' do
      expect(json['examples'].map { it.values_at('description', 'status') })
        .to eq([['shows the weather', 'passed'], ['keeps its state', 'failed']])
    end

    it "keeps a failure's message" do
      expect(json['examples'].last['message']).to eq('expected 5, got 4')
    end

    it "copies a screen's PNG beside the report, with its outlines and problems" do
      shown = json['examples'].first['screens'].first

      expect([File.exist?(File.join(dir, shown['image'])), shown['outlines'].size, shown['problems']])
        .to eq([true, 1, ['failed to load https://x.test/a.png']])
    end

    it "records a transform run's time, memory and requests" do
      expect(json['examples'].last['runs'].first)
        .to include('duration_ms' => 120, 'max_memory_mb' => 40.5, 'requests' => [include('url' => 'https://api.test/a')])
    end

    it 'writes a page that shows the screens' do
      expect(File.read(File.join(dir, 'index.html'))).to include('shows the weather', 'images/1.png', 'og_png · full')
    end
  end

  context 'under GitHub Actions' do
    let(:summary) { File.join(dir, 'summary.md') }

    before do
      stub_const('ENV', ENV.to_h.merge('GITHUB_STEP_SUMMARY' => summary))
      report.example_passed(passed)
      report.example_failed(failed)
      report.close(nil)
    end

    it 'adds the counts and the failures to the step summary' do
      expect(File.read(summary)).to include('1 passed, 1 failed', 'keeps its state')
    end
  end

  it 'leaves out a run whose transform did not run' do
    example_running(passed) { report.record_run(double('run', duration_ms: nil)) }
    report.example_passed(passed)
    report.close(nil)

    expect(JSON.parse(File.read(File.join(dir, 'report.json')))['examples'].first['runs']).to be_empty
  end

  it 'records nothing outside an example' do
    allow(RSpec).to receive(:current_example).and_return(nil)
    report.record_screen(screen)
    report.close(nil)

    expect(JSON.parse(File.read(File.join(dir, 'report.json')))['examples']).to be_empty
  end
end
