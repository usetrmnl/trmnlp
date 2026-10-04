# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'
require 'trmnlp/testing/certificate_authority'
require 'trmnlp/testing/run'

RSpec.describe TRMNLP::Testing::Run do
  subject(:run) do
    described_class.new(plugin: plugin_dir, authority:, now: Time.utc(2030, 1, 2, 3, 4, 5),
                        custom_fields: { api_key: 'k1' }, state: { runs: 4 }, mocks:, **inputs)
  end

  let(:plugin_dir) { Dir.mktmpdir('trmnlp-run-plugin-') }
  let(:authority) { TRMNLP::Testing::CertificateAuthority.new }
  let(:inputs) { {} }
  let(:mocks) do
    { 'https://api.test/items?key=k1' => { json: { items: %w[a b] } }, 'https://api.test/extra' => { json: { word: 'mocked' } } }
  end

  before do
    write_plugin
    allow(TRMNLP::Testing::FrozenClock).to receive(:environment).and_return({})
  end

  after do
    authority.remove
    FileUtils.remove_entry(plugin_dir)
  end

  def write_plugin
    src = File.join(plugin_dir, 'src')
    FileUtils.mkdir_p(src)
    File.write(File.join(plugin_dir, '.trmnlp.yml'), '{}')
    settings = "name: Probe\nstrategy: polling\npolling_url: https://api.test/items?key={{ api_key }}\n"
    File.write(File.join(src, 'settings.yml'), settings)
    File.write(File.join(src, 'transform.rb'), <<~RUBY)
      require 'net/http'
      require 'json'
      def run(input)
        word = JSON.parse(Net::HTTP.get(URI('https://api.test/extra')))['word']
        runs = input.dig('trmnl', 'state', 'runs').to_i + 1
        { 'items' => input['items'], 'word' => word, 'runs' => runs, 'trmnl_state' => { 'runs' => runs } }
      end
    RUBY
    File.write(File.join(src, 'full.liquid'), '<p>{{ items | join: "," }} {{ word }} {{ "now" | date: "%Y" }}</p>')
  end

  describe '#transform' do
    let(:result) { run.transform }

    it 'polls through the mocks and runs the transform, whose own request is mocked too' do
      expect(result.data).to include('items' => %w[a b], 'word' => 'mocked')
    end

    it 'starts from the given state and answers the next one' do
      expect(result.state).to eq('runs' => 5)
    end

    it 'records every request the run made' do
      expect(result.requests.map { it.values_at(:via, :url) })
        .to eq([[:polling, 'https://api.test/items?key=k1'], [:transform, 'https://api.test/extra']])
    end

    context 'with a lambda mock' do
      let(:mocks) { super().merge('https://api.test/extra' => ->(request) { { json: { word: request[:via].to_s } } }) }

      it 'answers with what it computes' do
        expect(result.data['word']).to eq('transform')
      end
    end

    context 'with libfaketime installed' do
      before do
        allow(TRMNLP::Testing::FrozenClock).to receive(:environment).and_call_original
        File.write(File.join(plugin_dir, 'src', 'transform.rb'), "def run(input) = { 'year' => Time.now.year }")
      end

      it "freezes the transform's own clock" do
        expect(result.data['year']).to eq(2030)
      end
    end

    context 'with a mock that moves the clock' do
      let(:mocks) { { 'https://api.test/extra' => { json: { word: 'w' }, advance_clock: 3600 } } }

      before do
        allow(TRMNLP::Testing::FrozenClock).to receive(:environment).and_call_original
        File.write(File.join(plugin_dir, 'src', 'transform.rb'), <<~RUBY)
          require 'net/http'
          def run(input)
            before = Time.now.to_i
            Net::HTTP.get(URI('https://api.test/extra'))
            { 'moved' => Time.now.to_i - before }
          end
        RUBY
      end

      it "moves the transform's clock when it answers" do
        expect(result.data['moved']).to be_within(5).of(3600)
      end
    end

    context 'with a mock slower than the transform will wait' do
      let(:mocks) { super().merge('https://api.test/extra' => { body: 'late', delay: 1 }) }

      before do
        File.write(File.join(plugin_dir, 'src', 'transform.rb'), <<~RUBY)
          require 'net/http'
          def run(input)
            Net::HTTP.start('api.test', 443, use_ssl: true, read_timeout: 0.3) { it.get('/extra') }
            {}
          rescue Net::ReadTimeout
            { 'gave_up' => true }
          end
        RUBY
      end

      it 'records the request as aborted' do
        expect(result.requests.find { it[:via] == :transform }).to include(aborted: true)
      end
    end

    it 'answers how long the transform ran' do
      expect(result.duration_ms).to be_positive
    end

    it 'answers the most memory the transform used' do
      expect(result.max_memory_mb).to be_positive
    end

    context 'with the transform turned off' do
      let(:inputs) { { transform: false } }

      it 'answers the polled data' do
        expect(result.data).not_to have_key('word')
      end
    end

    context 'with data given' do
      let(:inputs) { { data: { items: %w[given] } } }

      it 'skips polling' do
        expect(result.requests.map { it[:via] }).to eq([:transform])
      end
    end
  end

  describe '#render' do
    it "renders trmnlp's page with the transform's output at the frozen time" do
      expect(run.render(view: 'full').html).to include('<p>a,b mocked 2030</p>')
    end

    it 'answers the data the markup was rendered with' do
      expect(run.render(view: 'full').data).to include('items' => %w[a b], 'word' => 'mocked')
    end
  end
end
