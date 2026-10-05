# Testing Plugins

`trmnlp init` starts a plugin with `tests/plugin_spec.rb` (`it_behaves_like 'a publishable recipe'`, below) and a GitHub workflow that runs it in the `trmnl/trmnlp` image, uploads the report, can rewrite the snapshots on a manual run, and pushes to TRMNL only once lint and tests pass. `trmnlp test` runs the RSpec files in your plugin's `tests/` folder, through the same pipeline `serve` and `build` use, with fake APIs and a fixed clock:

```ruby
# tests/weather_spec.rb
RSpec.describe 'Weather' do
  let(:mocks) { { 'https://api.weather.example/*' => { json: { temp: 12 } } } }

  %w[og_plus v2].each do |device|
    it "shows the temperature on #{device}" do
      screen = trmnl.render(device:, now: '2030-01-02T08:00:00Z', custom_fields: { city: 'Amsterdam' }, mocks:)

      expect(screen).to have_text('12°')
      expect(screen).to have_no_overflow
      expect(screen.box('.title').bottom).to be <= screen.box('.content').top
      expect(screen).to match_snapshot
    end
  end

  it 'keeps its state when the API has nothing new' do
    run = trmnl.transform(state: { etag: 'abc' }, mocks: { 'https://api.weather.example/*' => { status: 304 } })

    expect(run.state).to eq('etag' => 'abc')
  end
end
```

- `trmnl.transform(...)` runs the transform and answers `data`, `state`, `requests`, `log`, `error`, `duration_ms` and `max_memory_mb`; `expect(run).to stay_within_serverless_limits` checks TRMNL's 5 seconds and 128 MB. `trmnl.render(view: 'full', ...)` renders a view in Firefox and answers a screen: Capybara's matchers (`have_text`, `have_css`, `within`...) see what is drawn, and `box(selector)`, `evaluate(js)`, `overflowing` and `problems` (script errors, unhandled rejections, `console.error` and files that failed to load; `have_no_problems`) ask the live page; `fresh_browser: true` renders in a new Firefox with nothing cached; `screen.result` holds the run's `data`, `state` and `requests`. `trmnl.plugin(dir)` tests the plugin in another folder, such as a built copy.
- Inputs, all optional: `device:` (a TRMNL model name, or `{ width:, height:, bit_depth: }`), `palette:`, `orientation: :portrait`, `dark_mode:`, `theme:`, `now:`, `custom_fields:`, `variables:`, `state:`, `previous_merge_variables:`, `data:` (the plugin's data: skips polling, and replaces a static plugin's `static_data`), `transform: false`. A test's `custom_fields` and `variables` replace those in `.trmnlp.yml`, so development values there never reach a test; the field defaults in `settings.yml` still apply, as on TRMNL.
- A board drawn by its own script takes `head:` (markup added to the page's `<head>`) and `wait_for:` (a JavaScript expression the page must reach before it is captured, within `wait_for_timeout:` seconds); without it, the capture freezes timers once TRMNL's readiness flags are set.
- `mocks:` answer every request the run makes: polling urls, and the transform's own requests in any language, HTTPS included. Keys are urls, with `*` wildcards, a Regexp, or a method first (`'POST https://...'`). Values are `{ json:, body:, status:, headers:, delay:, body_delay:, advance_clock:, error: :reset }` (times in seconds: `body_delay:` sends the headers first and the body later, `advance_clock:` moves the transform's clock on when it answers), a string body, a lambda that takes the request, or an array of answers used in order. An unmocked request gets a 599. `requests` lists every request with its `status`, and `aborted: true` for one the transform gave up on before its answer arrived; `duration_ms` is how long the transform ran.
- `now:` starts every clock: Liquid's, the markup's scripts', and the transform's, through libfaketime (`brew install libfaketime` or `apt-get install libfaketime`; already in the Docker image). On macOS the interpreter must come from brew, mise or similar, since macOS will not hand libfaketime to its own `/usr/bin` binaries. The markup's scripts see `now:` as the page starts, and the clock runs on from there, as on TRMNL; `Date()` and an `Intl.DateTimeFormat` given no date use it too.
- `trmnlp test --report report` also writes `report/index.html` and `report/report.json`: every example with each screen it rendered (with a switch that outlines every drawn box, and the page's problems) and each transform it ran (time, memory, requests). Under GitHub Actions the counts and failures go to the run's summary too.
- `it_behaves_like 'a publishable recipe'` is what a recipe should hold before it is published: every view draws without page errors on the TRMNL OG (1-bit, and 2-bit in landscape and portrait) and the TRMNL X (landscape and portrait), and the transform runs without error within TRMNL's limits. Every screen is also checked for leaked values (`undefined`, `NaN`, `null`, `[object Object]`, `Liquid error`, raw `{{`); the full view must still draw when the API answers with nothing, answers 500 or cannot be reached; and it is drawn with each option of every select field (the first and last when a field has more than 20). It uses the group's `mocks`, `custom_fields`, `variables` and `now` when the group defines them; `screens: [{ device: 'kobo_libra_2' }, ...]` draws on other devices. It leaves overflow out, since `have_no_overflow` also flags text cut short on purpose (`text-overflow: ellipsis`, `-webkit-line-clamp`); call it in your own examples where it fits.
- `trmnlp test` opens each page from a local address, `http://127.0.0.1:<port>/pages/<id>`, where TRMNL writes its page into `about:blank`. Pages that share an address share Firefox's parsed copy of the Framework's 15 MB stylesheet, so it is parsed once for the run, and a page's scripts run after its stylesheets apply. As on `about:blank`, the page gets no `localStorage`, `sessionStorage`, `indexedDB` or cookies and sends no `Referer`. What still differs: `location` is that address, a cross-origin request carries it as its `Origin` where TRMNL's carries `null`, and a relative URL is asked of the local address (and is not found) where TRMNL resolves it against `about:blank`.
- `have_qr_code` passes when a QR code scans in the PNG, so in what the device shows after quantizing; `have_qr_code('https://example.com/pay')` or `have_qr_code(/pay/)` also checks its text, `within: '.code'` scans one element only, and `screen.qr_codes` lists every text found. zbar reads dark codes on a light background only, so a light code on a dark background is reported as no code. It needs zbar (`brew install zbar` or `apt-get install zbar-tools`; already in the Docker image).
- `match_snapshot` stores a missing snapshot under `tests/snapshots/<os>/` and fails one on CI; `trmnlp test --update` rewrites them. Fonts render differently per operating system, so run tests in the Docker image when CI should share your snapshots. `fit_image_size_limit` checks the PNG against the model's limit, `have_no_leaked_text` the drawn text for leaked values, and `have_no_transform_error` a render's transform.

## Sharing setup between spec files

Put setup that several spec files need, such as shared examples or helper methods, in `tests/spec_helper.rb`, and add a `.rspec` file to the plugin's folder that loads it before the specs:

```
--require ./tests/spec_helper.rb
```

## Running tests in parallel

`trmnlp test` runs one example at a time in one Firefox. To spread the spec files over several processes, each with its own Firefox, use the [parallel_tests](https://github.com/grosser/parallel_tests) gem from the plugin's folder:

```sh
gem install parallel_tests
PARALLEL_TESTS_EXECUTABLE="trmnlp test --dir ." parallel_rspec -n 3 tests/
```

Files, not examples, are shared out, so a cache that a spec file builds for its own examples still works. Add `--report report` to the executable for a report per process: `report/`, `report2/`, `report3/`.
