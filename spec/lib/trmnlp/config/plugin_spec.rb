# frozen_string_literal: true

require 'spec_helper'
require 'tmpdir'

RSpec.describe TRMNLP::Config::Plugin do
  subject(:plugin) { described_class.new(paths, project_config) }

  let(:root_dir) { File.join(__dir__, '../../../fixtures') }
  let(:paths) { TRMNLP::Paths.new(root_dir) }
  let(:project_config) { TRMNLP::Config::Project.new(paths) }

  describe '#polling_headers' do
    context 'with a plain key=value pair' do
      before { plugin.instance_variable_set(:@config, { 'polling_headers' => 'Authorization=Bearer abc' }) }

      it 'parses into a hash' do
        expect(plugin.polling_headers).to eq({ 'Authorization' => 'Bearer abc' })
      end
    end

    context 'with one header per line, as the hosted form saves them' do
      before { plugin.instance_variable_set(:@config, { 'polling_headers' => "Accept=*/*\r\nAccept-Language=en-US" }) }

      it 'splits on the line breaks' do
        expect(plugin.polling_headers).to eq({ 'Accept' => '*/*', 'Accept-Language' => 'en-US' })
      end
    end

    context 'with Name: Value headers' do
      before { plugin.instance_variable_set(:@config, { 'polling_headers' => "Accept: */*\nReferer: https://a.test/?x=1" }) }

      it 'splits each header on the colon' do
        expect(plugin.polling_headers).to eq({ 'Accept' => '*/*', 'Referer' => 'https://a.test/?x=1' })
      end
    end

    context 'with a JSON object' do
      let(:json) { '{"Notion-Version": "2022-06-28", "X-Retries": 2}' }

      before { plugin.instance_variable_set(:@config, { 'polling_headers' => json }) }

      it 'answers its keys and values as strings' do
        expect(plugin.polling_headers).to eq({ 'Notion-Version' => '2022-06-28', 'X-Retries' => '2' })
      end
    end

    context 'with an = inside the value' do
      before { plugin.instance_variable_set(:@config, { 'polling_headers' => 'Authorization=Basic dXNlcjpwYXNz==' }) }

      it 'keeps the whole value' do
        expect(plugin.polling_headers).to eq({ 'Authorization' => 'Basic dXNlcjpwYXNz==' })
      end
    end

    context 'with a Liquid conditional that spans the whole string' do
      before do
        config = { 'polling_headers' => '{% if character_name %}Greeting=hello {{ character_name }}{% endif %}' }
        plugin.instance_variable_set(:@config, config)
      end

      it 'renders the conditional before parsing key=value pairs (issue #79)' do
        expect(plugin.polling_headers).to eq({ 'Greeting' => 'hello Bluey' })
      end
    end

    context 'with a Liquid conditional whose render is empty' do
      before do
        config = { 'polling_headers' => '{% if missing_field %}Authorization=Bearer {{ missing_field }}{% endif %}' }
        plugin.instance_variable_set(:@config, config)
      end

      it 'returns an empty hash' do
        expect(plugin.polling_headers).to eq({})
      end
    end
  end

  describe 'oauth variable injection' do
    it 'injects extra variables into polling_headers' do
      plugin.instance_variable_set(:@config, { 'polling_headers' => 'Authorization=Bearer {{ oauth_access_token }}' })
      expect(plugin.polling_headers(extra_variables: { 'oauth_access_token' => 'AT' }))
        .to eq({ 'Authorization' => 'Bearer AT' })
    end

    it 'injects extra variables into polling_urls' do
      plugin.instance_variable_set(:@config, { 'polling_url' => 'https://api.test/?t={{ oauth_access_token }}' })
      expect(plugin.polling_urls(extra_variables: { 'oauth_access_token' => 'AT' }))
        .to eq(['https://api.test/?t=AT'])
    end

    it 'injects extra variables into polling_body' do
      plugin.instance_variable_set(:@config, { 'polling_body' => 'token={{ oauth_access_token }}' })
      expect(plugin.polling_body(extra_variables: { 'oauth_access_token' => 'AT' })).to eq('token=AT')
    end
  end

  describe '#polling_urls' do
    before { plugin.instance_variable_set(:@config, { 'polling_url' => "https://a.test/1\r\n\n  https://a.test/2  \n" }) }

    it 'reads one url per line, squished, without blank lines' do
      expect(plugin.polling_urls).to eq(%w[https://a.test/1 https://a.test/2])
    end
  end

  describe '#polling_url_text' do
    before { plugin.instance_variable_set(:@config, { 'polling_url' => 'https://a.test/{{ city }}' }) }

    it 'answers the url unrendered, as TRMNL exposes it to markup' do
      expect(plugin.polling_url_text).to eq('https://a.test/{{ city }}')
    end
  end

  describe '#custom_fields_values' do
    let(:fields) do
      [{ 'keyname' => 'city', 'default' => 'Paris' },
       { 'keyname' => 'units', 'field_type' => 'select', 'options' => %w[Metric Imperial] }]
    end

    before { plugin.instance_variable_set(:@config, { 'custom_fields' => fields }) }

    it 'fills a blank value with its default' do
      allow(project_config).to receive(:custom_fields).and_return('city' => ' ')

      expect(plugin.custom_fields_values['city']).to eq('Paris')
    end

    it 'fills a missing value with its default' do
      allow(project_config).to receive(:custom_fields).and_return({})

      expect(plugin.custom_fields_values).to eq('city' => 'Paris')
    end

    it 'keeps false as an answer' do
      allow(project_config).to receive(:custom_fields).and_return('city' => 'false')

      expect(plugin.custom_fields_values['city']).to eq('false')
    end

    it 'fills in an env value, which the markup and the polling url both see' do
      allow(ENV).to receive(:to_h).and_return('ICAO' => 'KSFO')
      allow(project_config).to receive(:custom_fields).and_return('station' => '{{ env.ICAO }}')

      expect(plugin.custom_fields_values['station']).to eq('KSFO')
    end

    it "saves a select's label as its value" do
      allow(project_config).to receive(:custom_fields).and_return('units' => 'Metric')

      expect(plugin.custom_fields_values['units']).to eq('metric')
    end
  end

  describe '#missing_required_fields' do
    let(:fields) do
      [{ 'keyname' => 'api_key' }, { 'keyname' => 'city' }, { 'keyname' => 'zip', 'optional' => true },
       { 'keyname' => 'units', 'default' => 'si' }, { 'keyname' => 'debug', 'field_type' => 'boolean' }]
    end
    let(:url) do
      'https://a.test/?key={{ api_key }}&city={{ city | default: "Paris" }}&zip={{ zip }}&u={{ units }}&d={{ debug }}'
    end

    before { plugin.instance_variable_set(:@config, { 'custom_fields' => fields, 'polling_url' => url }) }

    it 'names a blank field the url needs without a default' do
      allow(project_config).to receive(:custom_fields).and_return({})

      expect(plugin.missing_required_fields).to eq(['api_key'])
    end

    it 'answers none once the field is filled in' do
      allow(project_config).to receive(:custom_fields).and_return('api_key' => 'abc')

      expect(plugin.missing_required_fields).to eq([])
    end

    it 'reads the full trmnl path to a field' do
      url = 'https://a.test/{{ trmnl.plugin_settings.custom_fields_values.city }}'
      plugin.instance_variable_set(:@config, { 'custom_fields' => fields, 'polling_url' => url })
      allow(project_config).to receive(:custom_fields).and_return({})

      expect(plugin.missing_required_fields).to eq(['city'])
    end
  end

  describe '#static_data' do
    before { plugin.instance_variable_set(:@config, { 'static_data' => static_data }) }

    context 'when it is blank, as TRMNL saves a static plugin with no data' do
      let(:static_data) { '  ' }

      it 'is empty' do
        expect(plugin.static_data).to eq({})
      end
    end

    context 'when it starts with a byte order mark' do
      let(:static_data) { "\uFEFF{\"city\": \"Lisbon\"}" }

      it 'parses after it' do
        expect(plugin.static_data).to eq('city' => 'Lisbon')
      end
    end

    context 'when it is not JSON' do
      let(:static_data) { '{city' }

      it 'raises' do
        expect { plugin.static_data }.to raise_error(TRMNLP::InvalidConfig, 'invalid JSON in static_data')
      end
    end
  end

  describe '#framework_version' do
    context 'when settings.yml pins a version' do
      let(:pinned) { TRMNLP::FrameworkVersion.version_numbers.first }
      before { plugin.instance_variable_set(:@config, { 'framework_version' => pinned }) }

      it 'resolves that pinned version' do
        expect(plugin.framework_version).to eq(TRMNLP::FrameworkVersion.new(pinned))
      end
    end

    context 'when settings.yml omits framework_version' do
      before { plugin.instance_variable_set(:@config, {}) }

      it 'falls back to the latest version' do
        expect(plugin.framework_version).to eq(TRMNLP::FrameworkVersion.latest)
      end
    end

    context 'when settings.yml names a version newer than the manifest' do
      before { plugin.instance_variable_set(:@config, { 'framework_version' => '9.9.9' }) }

      it 'resolves it rather than failing on a stale manifest' do
        expect(plugin.framework_version.number).to eq('9.9.9')
      end
    end

    context 'when settings.yml names a malformed version' do
      before { plugin.instance_variable_set(:@config, { 'framework_version' => 'v3-beta!' }) }

      it 'raises a typed InvalidConfig error' do
        expect { plugin.framework_version }.to raise_error(TRMNLP::InvalidConfig, /v3-beta!/)
      end
    end
  end

  describe '#custom_field_definitions' do
    context 'when settings.yml declares custom_fields' do
      let(:fields) { [{ 'keyname' => 'api_key', 'name' => 'API Key', 'field_type' => 'password' }] }
      before { plugin.instance_variable_set(:@config, { 'custom_fields' => fields }) }

      it 'returns the declared definitions' do
        expect(plugin.custom_field_definitions).to eq(fields)
      end
    end

    context 'when settings.yml omits custom_fields' do
      before { plugin.instance_variable_set(:@config, {}) }

      it 'returns an empty list' do
        expect(plugin.custom_field_definitions).to eq([])
      end
    end
  end

  describe '#serverless_language' do
    context 'when settings.yml sets a language' do
      before { plugin.instance_variable_set(:@config, { 'serverless_language' => 'python' }) }

      it 'returns the configured language' do
        expect(plugin.serverless_language).to eq('python')
      end
    end

    context "when settings.yml has serverless_language: ''" do
      before { plugin.instance_variable_set(:@config, { 'serverless_language' => '' }) }

      it 'returns nil so the inferred extension wins' do
        expect(plugin.serverless_language).to be_nil
      end
    end

    context 'when settings.yml omits serverless_language' do
      before { plugin.instance_variable_set(:@config, {}) }

      it 'returns nil' do
        expect(plugin.serverless_language).to be_nil
      end
    end
  end

  describe '#reload!' do
    it 'raises a readable InvalidConfig when settings.yml is not valid YAML' do
      Dir.mktmpdir('trmnlp-plugin-') do |dir|
        FileUtils.mkdir_p(File.join(dir, 'src'))
        File.write(File.join(dir, 'src', 'settings.yml'), 'name: [unclosed')
        bad_paths = TRMNLP::Paths.new(dir)

        expect { described_class.new(bad_paths, TRMNLP::Config::Project.new(bad_paths)) }
          .to raise_error(TRMNLP::InvalidConfig, /settings\.yml is not valid YAML/)
      end
    end
  end
end
