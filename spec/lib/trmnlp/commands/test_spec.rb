# frozen_string_literal: true

require 'spec_helper'
require 'json'
require 'open3'
require 'tmpdir'

# Runs `trmnlp test` for real: RSpec, the pipeline, Firefox and the matchers, on a plugin with its own tests.
RSpec.describe 'trmnlp test' do
  let(:plugin_dir) { Dir.mktmpdir('trmnlp-test-command-') }
  let(:trmnlp) { File.expand_path('../../../../bin/trmnlp', __dir__) }
  let(:spec_body) do
    <<~RUBY
      device = { width: 800, height: 480, bit_depth: 1, screen_classes: 'screen screen--1bit screen--og_png screen--md' }

      RSpec.describe 'Greeting' do
        it 'transforms the mocked answer' do
          expect(trmnl.transform(device:, mocks: { 'https://api.test/*' => { json: { name: 'Ada' } } }).data)
            .to include('greeting' => 'Hello Ada')
        end

        it 'shows it on the screen' do
          screen = trmnl.render(device:, mocks: { 'https://api.test/*' => { json: { name: 'Ada' } } })
          expect(screen).to have_css('.title', text: 'Hello Ada').and have_no_overflow
          expect(screen).to match_snapshot
        end

        it 'reports no problems on a clean page' do
          expect(trmnl.render(device:, data: { name: 'Ada' }, transform: false)).to have_no_problems
        end

        it 'reports what went wrong on the page' do
          broken = '<script>throw new Error("boom")</script><img src="https://missing.invalid/a.png">'
          problems = trmnl.render(device:, data: { name: 'Ada' }, transform: false, head: broken).problems
          expect(problems).to include(a_string_including('boom'), a_string_including('failed to load https://missing.invalid'))
        end

        it 'renders in a fresh browser when asked' do
          screen = trmnl.render(device:, data: { name: 'Ada' }, transform: false, fresh_browser: true)
          expect(screen.evaluate('document.querySelector(".title") !== null')).to be(true)
        end

        it 'renders narrower than a Firefox window can be, as an OG in portrait' do
          screen = trmnl.render(device: { width: 480, height: 800 }, data: { name: 'Ada' }, transform: false)
          expect(screen.evaluate('[innerWidth, innerHeight]')).to eq([480, 800])
        end

        it 'tests another plugin folder' do
          expect(trmnl.plugin(Dir.pwd).transform(device:, data: { name: 'Bo' }).data).to include('greeting' => 'Hello Bo')
        end

        it 'waits for a page that finishes drawing late' do
          screen = trmnl.render(device:, data: { name: 'Ada' }, transform: false,
                                head: '<script>window.drawLater = () => setTimeout(() => window.drawn = true, 300);</script>',
                                wait_for: 'window.drawLater && (window.drawStarted ||= (window.drawLater(), true)) && window.drawn')
          expect(screen.evaluate('window.drawn')).to be(true)
        end
      end
    RUBY
  end

  before do
    src = File.join(plugin_dir, 'src')
    FileUtils.mkdir_p([src, File.join(plugin_dir, 'tests')])
    File.write(File.join(plugin_dir, '.trmnlp.yml'), '{}')
    File.write(File.join(src, 'settings.yml'), "name: Greeting\nstrategy: polling\npolling_url: https://api.test/person\n")
    File.write(File.join(src, 'transform.rb'), "def run(input) = { 'greeting' => \"Hello \#{input['name']}\" }")
    File.write(File.join(src, 'full.liquid'), '<div class="layout"><span class="title">{{ greeting }}</span></div>')
    File.write(File.join(plugin_dir, 'tests', 'greeting_spec.rb'), spec_body)
  end

  after { FileUtils.remove_entry(plugin_dir) }

  def run_tests(*options)
    Open3.capture2e({ 'CI' => nil }, RbConfig.ruby, trmnlp, 'test', '--dir', plugin_dir, *options)
  end

  it 'passes a plugin whose tests hold' do
    output, _status = run_tests

    expect(output).to include('8 examples, 0 failures')
  end

  it 'exits cleanly when they hold' do
    expect(run_tests.last).to be_success
  end

  context 'with --report' do
    let(:report_dir) { File.join(plugin_dir, 'report') }
    let(:report) { JSON.parse(File.read(File.join(report_dir, 'report.json'))) }

    before { run_tests('--report', report_dir) }

    it 'writes the page' do
      expect(File.read(File.join(report_dir, 'index.html'))).to include('shows it on the screen')
    end

    it 'keeps each screen it rendered, with the boxes it drew' do
      screen = report['examples'].flat_map { it['screens'] }.first

      expect([File.exist?(File.join(report_dir, screen['image'])), screen['outlines']])
        .to match([true, include(include('tag' => 'span'))])
    end
  end

  context 'with --fast' do
    let(:spec_body) do
      <<~RUBY
        device = { width: 800, height: 480, bit_depth: 1, screen_classes: 'screen screen--1bit screen--og_png screen--md' }

        RSpec.describe 'Greeting' do
          it 'opens the page from a local address, where its scripts find the stylesheets applied' do
            head = '<script>window.seen = getComputedStyle(document.documentElement).getPropertyValue("--black");</script>'
            screen = trmnl.render(device:, data: { name: 'Ada' }, transform: false, head:)
            expect(screen.evaluate('[location.origin, window.seen]'))
              .to match([start_with('http://127.0.0.1:'), a_string_matching(/\\S/)])
          end

          it 'draws the same picture' do
            expect(trmnl.render(device:, data: { name: 'Ada' })).to have_css('.title', text: 'Hello Ada').and match_snapshot
          end
        end
      RUBY
    end

    it 'opens each page from a local address, and draws what it drew without' do
      run_tests('--update', 'tests') # without --fast: stores the picture; its local address example fails
      output, = Open3.capture2e({ 'CI' => 'true' }, RbConfig.ruby, trmnlp, 'test', '--fast', '--dir', plugin_dir)

      expect(output).to include('2 examples, 0 failures')
    end
  end

  context "with the publishable recipe's examples" do
    let(:greeting_markup) { '<div class="layout"><span class="title">{{ greeting }}</span></div>' }
    let(:quadrant) { greeting_markup }
    let(:spec_body) do
      <<~RUBY
        RSpec.describe 'Greeting' do
          let(:mocks) { { 'https://api.test/*' => { json: { name: 'Ada' } } } }

          it_behaves_like 'a publishable recipe', screens: [{ device: { model: 'og_test', width: 800, height: 480 } }]
        end
      RUBY
    end

    before do
      %w[half_horizontal half_vertical].each do |view|
        File.write(File.join(plugin_dir, 'src', "#{view}.liquid"), greeting_markup)
      end
      File.write(File.join(plugin_dir, 'src', 'quadrant.liquid'), quadrant)
    end

    it 'draws every view, runs the transform, and draws when the API fails' do
      expect(run_tests.first).to include('9 examples, 0 failures')
    end

    context 'when a view shows a leaked value' do
      let(:quadrant) { greeting_markup.sub('{{ greeting }}', '{{ greeting }} undefined') }

      it 'names the view and the screen' do
        expect(run_tests.first).to include('draws the quadrant view on og_test without overflow or page errors')
      end
    end

    context 'with a select field' do
      before do
        File.write(File.join(plugin_dir, 'src', 'settings.yml'), <<~YAML)
          name: Greeting
          strategy: polling
          polling_url: https://api.test/person
          custom_fields:
            - keyname: mood
              field_type: select
              options: [Calm, { Very loud: loud }]
              default: calm
        YAML
        loud_leaks = "{% if trmnl.plugin_settings.custom_fields_values.mood == 'loud' %} NaN{% endif %}"
        File.write(File.join(plugin_dir, 'src', 'full.liquid'), greeting_markup.sub('</span>', "#{loud_leaks}</span>"))
      end

      it 'draws the full view with each option, and names the one that breaks' do
        expect(run_tests.first)
          .to include('draws the full view with mood set to loud').and include('11 examples, 1 failure')
      end
    end

    context 'when a view overflows' do
      let(:quadrant) { greeting_markup.sub('{{ greeting }}', 'Ada ' * 200).sub('">', '" style="white-space: nowrap">') }

      it 'names the view and the screen' do
        expect(run_tests.first).to include('draws the quadrant view on og_test without overflow or page errors')
      end
    end
  end

  context 'with now: on a render' do
    let(:spec_body) do
      <<~RUBY
        device = { width: 800, height: 480 }
        now = '2030-01-02T03:04:05Z'
        page_scripts = '<script>window.startedAt = Date.now();</script>' \\
                       '<script>window.calledWithoutNew = Date();</script>' \\
                       '<script>window.formattedYear = new Intl.DateTimeFormat("en", { year: "numeric" }).format();</script>'

        RSpec.describe 'Page clock' do
          let(:screen) { trmnl.render(device:, data: { name: 'Ada' }, transform: false, now:, head: page_scripts) }

          it 'starts at now: when the page runs, not when the test builds it' do
            expect(screen.evaluate('window.startedAt') - (Time.iso8601(now).to_f * 1000)).to be_between(0, 1000)
          end

          it 'answers Date() called without new' do
            expect(screen.evaluate('window.calledWithoutNew')).to include('2030')
          end

          it 'formats a date given no argument at now:' do
            expect(screen.evaluate('window.formattedYear')).to eq('2030')
          end
        end
      RUBY
    end

    it 'gives page scripts a clock that starts at now:' do
      expect(run_tests.first).to include('3 examples, 0 failures')
    end
  end

  context 'when a test does not hold' do
    let(:spec_body) do
      "RSpec.describe('Greeting') { it('shows the name') { expect(trmnl.render(device: { width: 800, height: 480 }, " \
        "data: { name: 'Ada' })).to have_text('Grace') } }"
    end

    it 'names what it looked for' do
      expect(run_tests.first).to include('expected to find text "Grace"')
    end

    it 'exits with a failure' do
      expect(run_tests.last).not_to be_success
    end
  end
end
