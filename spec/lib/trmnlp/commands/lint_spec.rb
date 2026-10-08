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
    File.write(File.join(tmp_root, 'src', 'settings.yml'), <<~YAML)
      custom_fields:
        - keyname: about
          field_type: author_bio
          name: About
          email_address: me@example.com
    YAML
  end

  after { FileUtils.rm_rf(tmp_root) }

  describe '#call' do
    context 'with JSON output' do
      subject(:command) do
        json_options = described_class::Options.new(dir: tmp_root, quiet: true, format: 'json')
        described_class.new(context:, options: json_options, reporter:)
      end

      it 'emits exactly one parseable clean report' do
        expect(command.call).to be(true)
        expect(reporter.messages.size).to eq(1)
        expect(JSON.parse(reporter.messages.first)).to eq('version' => 1, 'passed' => true, 'issues' => [])
      end

      it 'preserves the failing result and reports all matching source locations' do
        File.write(File.join(tmp_root, 'src', 'full.liquid'), "\n\n<p>é</p><div style=\"opacity:0.5\">Text</div>\n")
        File.write(File.join(tmp_root, 'src', 'shared.liquid'),
                   "<p>Visible text</p>\n<div style=\"opacity:0.5\">Shared</div>\n")

        expect(command.call).to be(false)
        expect(reporter.messages.size).to eq(1)
        report = JSON.parse(reporter.messages.first)
        expect(report['passed']).to be(false)
        issue = report['issues'].find { |finding| finding['rule_id'] == 'no_opacity' }
        expect(issue['severity']).to eq('error')
        expect(issue['locations']).to contain_exactly(
          { 'path' => 'src/full.liquid', 'line' => 3, 'column' => 21,
            'snippet' => '<p>é</p><div style="opacity:0.5">Text</div>' },
          { 'path' => 'src/shared.liquid', 'line' => 2, 'column' => 13,
            'snippet' => '<div style="opacity:0.5">Shared</div>' }
        )
      end

      it 'attributes duplicate form-field errors to both declarations' do
        File.write(File.join(tmp_root, 'src', 'settings.yml'), <<~YAML)
          custom_fields:
            - keyname: first
            - keyname: second
        YAML
        command.call
        issues = JSON.parse(reporter.messages.first)['issues']
        issue = issues.find { |finding| finding['message'].include?('missing required key: name') }
        expect(issue['rule_id']).to eq('form_fields_valid')
        expect(issue['locations'].map { |location| location['line'] }).to eq([2, 3])
      end

      it 'omits unused custom-field values from report excerpts' do
        File.write(File.join(tmp_root, '.trmnlp.yml'), "custom_fields:\n  api_key: private-value\n")
        command.call
        expect(reporter.messages.join).not_to include('private-value')
        issue = JSON.parse(reporter.messages.first)['issues'].find do |finding|
          finding['rule_id'] == 'custom_fields_used'
        end
        expect(issue['locations'].first).to include('path' => '.trmnlp.yml', 'line' => 2,
                                                    'snippet' => 'api_key: [value omitted]')
      end

      it 'locates only failing image URLs without fetching them again for reporting' do
        valid = stub_request(:get, 'https://example.com/good.png').to_return(status: 200)
        broken = stub_request(:get, 'https://example.com/broken.png').to_return(status: 404)
        File.write(File.join(tmp_root, 'src', 'shared.liquid'), <<~HTML)
          <img src="https://example.com/good.png">
          <img src="https://example.com/broken.png">
        HTML
        command.call
        issue = JSON.parse(reporter.messages.first)['issues'].find do |finding|
          finding['rule_id'] == 'image_links_reachable'
        end
        expect(issue['locations'].map { |location| location['line'] }).to eq([2])
        expect(valid).to have_been_requested.once
        expect(broken).to have_been_requested.once
      end

      it 'locates each use of a filter that only custom_filters defines' do
        File.write(File.join(tmp_root, 'filters.rb'), "module TrmnlpLintSpecFilter\n  def shout(input) = input\nend\n")
        File.write(File.join(tmp_root, '.trmnlp.yml'), "custom_filters:\n  TrmnlpLintSpecFilter: filters.rb\n")
        File.write(File.join(tmp_root, 'src', 'shared.liquid'), "<p>Visible text</p>\n<p>{{ name | shout }}</p>\n")
        command.call
        issue = JSON.parse(reporter.messages.first)['issues'].find do |finding|
          finding['rule_id'] == 'no_custom_filters'
        end
        expect(issue['locations']).to eq([{ 'path' => 'src/shared.liquid', 'line' => 2, 'column' => 4,
                                            'snippet' => '<p>{{ name | shout }}</p>' }])
      end

      it 'locates each use of a filter that TRMNL does not have' do
        File.write(File.join(tmp_root, 'src', 'shared.liquid'), "<p>Visible text</p>\n<p>{{ items | push: 'x' }}</p>\n")
        command.call
        issue = JSON.parse(reporter.messages.first)['issues'].find do |finding|
          finding['rule_id'] == 'no_unknown_filters'
        end
        expect(issue['locations']).to eq([{ 'path' => 'src/shared.liquid', 'line' => 2, 'column' => 4,
                                            'snippet' => "<p>{{ items | push: 'x' }}</p>" }])
      end

      it 'locates a setting using YAML positions including leading blank lines' do
        File.write(File.join(tmp_root, 'src', 'settings.yml'), "\n\nname: lowercase\n")
        command.call
        issue = JSON.parse(reporter.messages.first)['issues'].find { |finding| finding['rule_id'] == 'title_casing' }
        expect(issue['locations']).to eq([{ 'path' => 'src/settings.yml', 'line' => 3, 'column' => 7,
                                            'snippet' => 'name: lowercase' }])
      end

      it 'attributes an invalid framework class to each matching file' do
        File.write(File.join(tmp_root, 'src', 'full.liquid'), '<div class="w--[192px]">Text</div>')
        File.write(File.join(tmp_root, 'src', 'shared.liquid'), '<p class="w--[192px]">Shared</p>')
        command.call
        issue = JSON.parse(reporter.messages.first)['issues'].find do |finding|
          finding['rule_id'] == 'arbitrary_values_in_range'
        end
        expect(issue['locations'].map { |location| location['path'] }).to eq(%w[src/full.liquid src/shared.liquid])
      end

      it 'names each missing view when Shared provides no fallback content' do
        File.write(File.join(tmp_root, 'src', 'shared.liquid'), '')
        command.call
        issue = JSON.parse(reporter.messages.first)['issues'].find do |finding|
          finding['rule_id'] == 'layouts_have_content'
        end
        expect(issue['locations'].map { |location| location['path'] }).to eq(
          %w[src/full.liquid src/half_horizontal.liquid src/half_vertical.liquid src/quadrant.liquid]
        )
        expect(issue['locations']).to all(include('line' => 1, 'column' => 1, 'snippet' => ''))
      end
    end

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

    it 'includes a rule ID, a source location and an excerpt in text output' do
      File.write(File.join(tmp_root, 'src', 'full.liquid'), "\n<div style=\"opacity:0.5\">Text</div>\n")
      command.call
      expect(reporter.messages).to include(a_string_matching(/\[no_opacity\]/),
                                           a_string_matching(%r{src/full\.liquid:2:13}),
                                           a_string_matching(/opacity:0.5/))
    end

    context 'with a rule listed in ignored_lint_rules' do
      subject(:command) do
        json_options = described_class::Options.new(dir: tmp_root, quiet: true, format: 'json')
        described_class.new(context:, options: json_options, reporter:)
      end

      before do
        File.write(File.join(tmp_root, '.trmnlp.yml'), "ignored_lint_rules:\n  - no_opacity\n")
        File.write(File.join(tmp_root, 'src', 'shared.liquid'), '<div style="opacity:0.5">Text</div>')
      end

      it 'passes' do
        expect(command.call).to be(true)
      end

      it 'drops its findings from the JSON report' do
        command.call
        expect(JSON.parse(reporter.messages.first)).to eq('version' => 1, 'passed' => true, 'issues' => [])
      end

      it 'drops its findings from the text report' do
        text_command = described_class.new(context:, options: described_class::Options.new(dir: tmp_root, quiet: true),
                                           reporter:)
        text_command.call
        expect(reporter.messages).to include(a_string_matching(/All checks passed/))
      end
    end

    it 'raises naming the known rule IDs when ignored_lint_rules lists an unknown one' do
      File.write(File.join(tmp_root, '.trmnlp.yml'), "ignored_lint_rules:\n  - no_opacitee\n")

      expect { command.call }.to raise_error(TRMNLP::InvalidConfig, /no_opacitee.*no_opacity/m)
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
