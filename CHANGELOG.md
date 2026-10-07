
# Changelog

## Unreleased

- `trmnlp lint` reports a filter that neither Liquid nor trmnl-liquid defines (`no_unknown_filters`), such as a typo or a LiquidJS filter like `push`. TRMNL outputs the value unfiltered, and `serve` and `build` drew it the same way, so nothing showed the mistake.
- The Docker image includes geckodriver, so it draws screens on arm64 Linux such as a Raspberry Pi. Selenium downloaded it on every run that draws a screen (`test`, `build`, `serve`), which took about half a second and failed with no network, and on arm64 without x86 emulation it could not download one at all (`Unable to obtain geckodriver`).
- `have_no_overflow(except: '.forecast')` and `screen.overflowing(except:)` leave out a box that hides content on purpose, and everything inside it.

## 0.20.0

- `trmnlp lint` skips the rules listed under `ignored_lint_rules` in `.trmnlp.yml`, in text and JSON output alike. An unknown rule ID is an error that lists the known ones.
- `trmnlp lint`, `build` and `serve` accept the `hidden` field type, which TRMNL renders as a hidden input. They warned "unknown field_type: hidden".
- The README lists `trmnlp test` under Commands, and the guide to testing plugins moved to `docs/testing.md`, with how to share setup through `tests/spec_helper.rb`.
- `trmnlp test`: `have_qr_code` on an element wholly off the left or top of the screen finds no code. It scanned part of the screen instead, because ImageMagick reads a crop 0 pixels wide as the whole width.
- `it_behaves_like 'a publishable recipe'` no longer checks overflow. `have_no_overflow` flags text cut short on purpose (`text-overflow: ellipsis`, `-webkit-line-clamp`) on most list and calendar recipes, so authors filtered it out; the matcher stays for examples that call it.
- `have_no_overflow` passes text cut short on purpose (`text-overflow: ellipsis`, `-webkit-line-clamp`) and text whose font is taller than its line, when only the empty space below it is cut. It reports a box only when a child box or a glyph's ink crosses its edge, so cut descenders still fail, and it now reports a scrolling box (`overflow: auto` or `scroll`) whose content is cut.
- `have_no_problems` ignores Firefox's "ResizeObserver loop completed with undelivered notifications", which it raises when a ResizeObserver resizes what it observes, as FullCalendar does. Browsers report it as a page error, but nothing is broken.
- `it_behaves_like 'a publishable recipe'` also uses the group's `variables` (for Plugin Merge recipes) and `now` when the group defines them. It passed only `mocks` and `custom_fields`, so such a recipe was drawn without its variables and on the real clock.
- `trmnlp test`: under `now:`, the page's clock starts at `now:` when the page runs. It started seconds late, by however long Firefox took to load the page. `Date()` without `new` no longer throws, and `Intl.DateTimeFormat#format` and `#formatToParts` given no date use `now:`.
- `trmnlp test --report` writes a report per process under parallel_tests (`report`, `report2`, ...) instead of each process overwriting the last. The README shows how to run a plugin's tests in parallel.
- `serve`, `build` and `test` skip resizing the page when it is already the size asked for, and check a resize every 0.01 s instead of 0.1 s. About 0.04 s faster a render.
- The bundled list of Framework versions goes up to 3.4.0, so offline, `trmnlp build` and `serve` no longer warn that a plugin pinned to 3.3.0 or later is not a published version. A release refreshes the list before it builds the gem.
- The `qr_code` filter draws a white border four modules wide inside the code's box, so it scans in dark mode and on a dark page. The box keeps its size and the modules shrink to make room.
- `trmnlp test`: `data:` reaches a static plugin. It was ignored there, so the test rendered the `static_data` in `settings.yml`.
- `trmnlp test` takes a screen's PNG only when a test asks for it (`match_snapshot`, `fit_image_size_limit`, `png_path`, `--report`). A test that only reads the page no longer waits for the screenshot and its quantizing, about 0.15 seconds a render. The picture is of the page when it is first asked for, so a page changed with `evaluate` before `match_snapshot` is drawn changed.
- `trmnlp test` opens each page from a local address instead of writing it into `about:blank` with its stylesheets inlined, so Firefox parses the Framework's 15 MB stylesheet once for the run: 10 renders take 5.5 seconds where they took 10.1, and trmnlp's own suite 89 seconds where it took 114. The page still gets no storage, cookies or `Referer`, as on TRMNL. Its `location` and the `Origin` of its cross-origin requests are `http://127.0.0.1:<port>`, and a relative URL is not found. (#193)
- Every screenshot is 0.1 to 0.2 s faster, in `test`, `build` and `serve`. Stopping the page's timers before the capture cleared 100,000 timer ids one by one; it now clears only the ids the page has used.
- A font file that never arrives no longer hangs a render until WebDriver's 30 second limit (`Selenium::WebDriver::Error::ScriptTimeoutError: Timed out after 30000 ms`), in `test`, `build` and `serve`. The page is given 10 seconds for its fonts, loaded once more, and then fails with the names of the fonts still loading.
- `have_qr_code` checks that a QR code scans in a screen's PNG, and with a String or Regexp what it reads; `within:` scans one element and `screen.qr_codes` lists every text. It uses zbar, which the Docker image now includes.

## 0.19.0

- `it_behaves_like 'a publishable recipe'` also checks every screen for leaked values (`undefined`, `NaN`, `null`, `[object Object]`, `Liquid error`, raw `{{` or `{%`), draws the full view when the API answers with nothing, answers 500 or cannot be reached, and draws it with each option of every select field. New matchers: `have_no_leaked_text` and `have_no_transform_error`. (#181)

## 0.18.1

- Pages narrower than a Firefox window render, such as a 480x800 TRMNL OG in portrait, in `serve`, `build` and `test`. trmnlp sets the page's viewport with WebDriver BiDi, as TRMNL does, instead of resizing the window, which Firefox will not size under about 500px. (#178)
- `it_behaves_like 'a publishable recipe'` also draws every view on the TRMNL OG (2-bit) in portrait. (#179)

## 0.18.0

- `it_behaves_like 'a publishable recipe'` checks what a recipe should hold before it is published: every view draws without overflow or page errors on the TRMNL OG (1-bit and 2-bit) and the TRMNL X (landscape and portrait), and the transform runs without error within TRMNL's limits. `trmnlp init`'s starter spec uses it. (#176)

## 0.17.2

- `trmnlp test` no longer inlines a stylesheet link inside a script's string, such as a CDN fallback written with `document.write`. It broke the script, and every render came out blank. (#174)

## 0.17.1

- `trmnlp test --report` writes its images readable by everyone, and `--update` its snapshots. They kept the 0600 mode of the screen's temp file, so under the `trmnl/trmnlp` image, which runs as root, the init workflow could not upload the report. (#171)
- Capybara's matchers compose with `.and` and `.or` in a plugin's tests. (#172)

## 0.17.0

- `trmnlp init` adds a starter `tests/plugin_spec.rb`, and its GitHub workflow gains a `test` job: `trmnlp test --report` in the `trmnl/trmnlp` image (one `TRMNLP_IMAGE` setting picks the tag), the report uploaded, a manual `update_snapshots` run, and the push to TRMNL waiting for lint and tests. (#168)
- `trmnlp test --report DIR` writes a report of the run: every example with each screen it rendered (the PNG, an outline of every drawn box, the page's problems) and each transform it ran (time, memory, requests), as `DIR/index.html` and `DIR/report.json`. Under GitHub Actions it adds the counts and the failures to the run's summary. (#167)
- A polling plugin with no polling url runs its transform on empty data, as TRMNL does, instead of warning "config must specify polling_url" and counting it as a failed fetch, which stopped the transform's state being saved. A plugin whose transform fetches everything itself has no polling url. (#166)
- `trmnlp test` runs a plugin's RSpec files in `tests/` through trmnlp's own pipeline: `trmnl.transform` and `trmnl.render` with fake APIs (the transform's own HTTPS requests included, in any language), a fixed clock (libfaketime, macOS and Linux), saved state, any TRMNL device, Capybara's matchers on what Firefox drew, layout boxes, overflow checks and PNG snapshots. See the README's Testing Plugins section. (#165)
- A responsive `qr_code` keeps its own size, as on TRMNL. The hosted service gives the SVG a width, a height and `max-width:100%;height:auto` (core's `trmnl_liquid_qr_code_intrinsic_size` initializer), and trmnlp now does the same. Without it, a code in a shrink-to-fit container such as a `flex flex--col` column shrank to the width of its neighbors, or to nothing. (#162)
- The Framework script loads as a module, as on TRMNL. A module runs after the page is parsed, so a plugin script that calls the Framework straight away now fails locally the way it fails on the device, instead of only on the device. (#163)
- A transform's `trmnl_state` is not saved when the poll before it failed, as on TRMNL: a state built from an error or an empty response would replace the last good one. The key is still kept out of the rendered data. (#163)

## 0.16.0

- Webhook posts must wrap their data in `merge_variables`, as TRMNL requires, and `merge_strategy` (`replace`, `deep_merge`, or `stream` with `stream_limit`) works from the body or the query string. A post without the wrapper is refused with TRMNL's message and a 422; a body that is not JSON gets a 400. Before, trmnlp stored the raw body and always answered 200, so a correct post rendered its data under `merge_variables.*`. A post over 5 kB is stored with a warning, since trmnlp cannot know your plan's limit. (#155)
- Polled and posted data is cached per project, so two plugins no longer share one `data.json`. Data cached by an older trmnlp is not read: a polling plugin polls again on start, and a webhook plugin needs one new post. (#155)
- A webhook plugin with a transform runs it once, when a post arrives, and stores the result, as TRMNL does; renders no longer run it. A transform's `trmnl_state` comes back as `trmnl.state` on its next run and in the markup, and `trmnl.previous_merge_variables` carries what the last run stored. (#155)
- `trmnl.plugin_settings` carries the plugin's name as `instance_name`, plus `no_screen_padding` and `data_fetched_utc`; `polling_url` appears only for a polling plugin and is the unrendered url; `polling_headers` is gone. `trmnl.device` carries `orientation` from the picker. The `trmnl` namespace now wins over a `trmnl` key in fetched data, as on TRMNL. (#155, #158)
- `dark_mode: 'yes'` darkens every render, `trmnlp build` and PNGs included, and a dark render gets the bare `dark-mode` class Framework 1.x inverts on. The default font class is `screen--fonts-trmnl`, the picker's `screen--1x` is dropped, and a theme select adds `screen--theme-*` with the theme's stylesheet on Framework 3.2.0 and later. `window.I18n.andXMore` uses the user's locale. (#155)
- A select custom field saves what TRMNL saves: "New York" as `new_york`, a `{ Label: value }` option as its value. The editor saved the label, so `{% if units == "metric" %}` matched only on TRMNL. A label already in `.trmnlp.yml` is read as its value. (#158)
- A custom field's `default` fills a blank value, in the markup and in the polling url, headers and body, and a custom field set to `{{ env.X }}` in `.trmnlp.yml` reaches the markup filled in, as it already did for polling. Polling is skipped with TRMNL's "Plugin is not configured" message while a field the url needs is blank. (#158)
- Polling follows TRMNL: the url, headers and body render with the `trmnl` namespace; urls split on CR or LF and drop blank lines; a GET sends the polling body as its query string; up to 5 redirects are followed, dropping `Authorization` when the host changes; reads time out after 10 s with one retry; a 429 or 5xx is a failed fetch while a 4xx body still renders; CSV, markdown, a byte order mark and an unlisted content type parse as on TRMNL. A url that resolves to a private address gets a warning, since TRMNL refuses it, but is still fetched. Logs and warnings leave out the query string, which often holds an api key. (#158)
- Merge variables over 100 kB fail the render with TRMNL's message. A transform stops after 5 s, gets `trmnl.oauth` when an account is connected, keeps the last good output when it fails, and renders nothing from an output that is not an object. (#158)
- `l_word`, `l_date`, `pluralize` and `number_to_currency` render as on TRMNL in its 29 locales: `pluralize` gave "3 persons", `number_to_currency: "de"` gave `de1,234.50`, and any non-English `l_word` or `l_date` raised. The locale data is copied from trmnl-i18n and rails-i18n into `db/data/locales` by `rake i18n:sync`, so trmnlp needs no Rails gems. (#156)
- PNG renders follow TRMNL's renderer: a page dithers only when it asks for it with `image-dither`, otherwise it is posterized with TRMNL's ImageMagick steps, and the capture waits for the Framework's ready signals (up to 5 s, 12 s with a map). Highcharts charts rendered blank, since the unversioned CDN url refuses a page with no Referer; they now load TRMNL's 12.3.0 copy. Text is no longer drawn with antialiasing turned off, which brings it closer to TRMNL's own PNGs. (#157)
- The `async_polling` strategy works locally: `{{ callback_url }}` points at the preview server, and the callback answers as TRMNL does, 410 for a stale or expired request. The `plugin_merge` strategy works too: list each referenced plugin as `<keyname>_<id>: <path to its trmnlp project>` under `merged_plugins` in `.trmnlp.yml`, and the markup gets TRMNL's merged data. (#160)
- `trmnlp lint` reports a filter that only `custom_filters` in `.trmnlp.yml` defines (`no_custom_filters`). TRMNL does not load those modules and outputs the value unfiltered. (#159)

## 0.15.0

- `trmnlp lint` names where each finding is: a rule ID such as `[no_opacity]`, then the file, line and column with the source line. Before, it printed only the message, so you had to search every view and Shared for the cause. `trmnlp lint --format json` writes the same report as one JSON object (`version`, `passed`, `issues`) for CI. Exit statuses are unchanged, and the values of unused custom fields in `.trmnlp.yml` are never printed. (#153)
- The inline-style check counts real CSS declarations in `style` attributes, still with a limit of six. It counted eight property names anywhere in the markup, so `font-size` in an HTML comment or a `<style>` block failed while seven `style="color:red"` passed. Comments, scripts, text and `<style>` blocks no longer count, and declarations inside Liquid `{% if %}` branches all count. (#152)

## 0.14.2

- A failed transform prints its stderr once. The `transform failed:` line repeated the whole stack trace that the `transform stderr:` line had just printed; it now names only the exit code. The preview page still shows the full error. (#148)
- When a polling URL answers 401 and an OAuth account is connected, trmnlp refreshes the token and polls once more, as the hosted service does. Before, it refreshed only once the stored expiry had passed, so a token the provider revoked early kept failing until you reconnected. (#150)
- A polling response that is not a 200 still reaches the markup and the transform, as on the hosted service, with a warning for a status outside 2xx. trmnlp replaced it with `{}`, so a transform that follows a 202 "pending job" body (`job_id`, `poll`) got nothing locally. (#146)
- `trmnlp lint` reports bracketed Framework classes the Framework never generates, such as `w--[192px]` (sizes stop at 128px), `gap--[60px]` and `rounded--[51px]` (both stop at 50px), `h--[6cqw]` (height takes `cqh`) and, from 3.2.0, a screen-prefixed `md:gap--[20px]`. They match no CSS rule, so they do nothing: a flag sized `lg:w--[192px]` stayed at its smaller width on the X with no warning. The ranges are checked against every 3.x `plugins.css`, and plugins on Framework 2 or earlier are skipped, since v2 generated wider sizes. (#149)

## 0.14.1

- `trmnlp lint` reports a `recipe_overview` under 100 words. Below that, TRMNL serves the public recipe page with `robots: noindex`, so the recipe never appears in Google or other search engines, and nothing said so: the page looked fine, and only its HTML gave it away. A blank overview still passes, since private plugins have none. (#144)

## 0.14.0

- `trmnlp serve` and `build` print what the transform writes to stdout and stderr (`console.log`, `print`, `puts`), one `transform stdout:` / `transform stderr:` line each, so a transform can be debugged without returning its logs in the data. (#128)
- The OAuth token exchange and refresh honor `oauth_token_request_auth_method` the way the hosted service does: HTTP Basic only for `header`, otherwise the client credentials go in the request body. trmnlp used HTTP Basic whenever a client secret was set, so a provider that wants the credentials in the body rejected the callback with `invalid_client: client_id is required`. A plugin that relied on HTTP Basic locally sets `oauth_token_request_auth_method: header`, which the hosted service already needs. (#121)
- `polling_headers` are parsed the way the hosted service parses them: one header per line, `Name: Value` as well as `Name=Value`, a JSON object, and values that contain `=`. Before, trmnlp split only on `&`, so headers saved one per line made the whole poll fail with "cannot include CR/LF" and the markup and transform got no polled data (no `IDX_0`/`IDX_1`). (#127)
- `trmnlp lint` no longer reports a custom field as unused when only the serverless transform (`src/transform.{py,rb,php,js}`) reads it. Plugins that move their data handling into the transform, reading fields from `input["trmnl"]["plugin_settings"]["custom_fields_values"]`, got one "is not used in form fields or markup" warning per field. The check now searches the transform as well, and its message names it. (#136)

## 0.13.2

- `google_photos_picker`, `json`, `modal_trigger` and `oauth_provider_select` are known form field types, so `trmnlp lint`, `build` and `serve` no longer warn "unknown field_type" for them. The hosted service renders all four. (#137)
- The README documents `recipe_overview:` in `src/settings.yml`, the recipe page text that `trmnlp push` and `pull` already carry. (#138)

## 0.13.1

- `lat_lon` is a known form field type, so `trmnlp lint`, `build` and `serve` no longer warn "unknown field_type: lat_lon" for a location field. The vendored list in `db/data/form_fields.yml` predated the hosted service adding it. (#129)

## 0.13.0

- `trmnlp login` now accepts the scoped API keys trmnl.com issues with a `trmnl_` prefix, as well as `user_` account keys. It used to refuse them with "Invalid API key; did you copy it from the right place?" before checking them with the server. A scoped key needs the profile capability to log in, read to list and pull, and content to push. With delete as well, a failed first push removes the plugin it created. (#132)
- The local preview now fills the `trmnl` fields the hosted service added: `trmnl.device.model`, `bit_depth`, `firmware_version`, `refresh_interval_seconds`, `sleep_mode_enabled`, `sleep_start_time` and `sleep_end_time`, and `trmnl.plugin_settings.refresh_interval_minutes`. The model and bit depth follow the device picker, with `og_plus` and 2 when nothing is picked. (#131)

## 0.12.0

- `required_ruby_version` is now `>= 4.0`, matching the Ruby version trmnlp actually needs. It has understated the real floor since 0.4.0: both `xdg` (Ruby 4.0 in the 10.x series pinned since 0.8.0) and `trmnl-liquid` (Ruby 4.0 since 0.5.0) require more than the gemspec claimed. RubyGems resolves against the declared value, so `gem install trmnl_preview` on an older Ruby did not fail. It quietly walked backwards to the newest version whose dependency tree resolved, reporting "Successfully installed" for a build up to twenty months old. On Ruby 3.4 that was 0.7.1, and on Ruby 3.3 and below it was 0.3.2, which predates the Thor CLI and offers only `serve`, `build` and `version`. Asking for the current version explicitly (`gem install trmnl_preview -v 0.11.0`) crashed RubyGems inside its own conflict reporting rather than explaining the problem. Installing on an unsupported Ruby now stops with "requires Ruby version >= 4.0".
- Dependencies updated to their current releases. `trmnl-liquid` moves from 0.7.0 to 0.8.2, the only pin that excluded a newer release; every other dependency already resolved to its newest version on a fresh install. The two trmnl-liquid versions ship identical code and identical dependencies, so rendering is unchanged.

## 0.11.0

- `framework_version:` now resolves against the release manifest published by the design system, not only the version list shipped inside the gem, so a framework version released after your trmnlp install can be pinned without upgrading. The manifest is read once per run with a 2 second timeout. If the request fails, or the response is not a version list, the copy bundled in the gem is used and rendering continues. That bundled copy is refreshed here too: `latest` moves from 3.1.1 to 3.2.0.
- `rake framework:sync` reads the published manifest by default. Pass a local design-system checkout (`rake framework:sync[/path/to/repo]`) for the previous behaviour.

## 0.10.0

- Added support for the `description` plugin setting, an optional one-line summary of the plugin. `trmnlp init` scaffolds the key in `src/settings.yml`, `trmnlp lint` reports descriptions longer than 35 characters (the hosted service's limit), and `trmnlp list` shows a DESCRIPTION column when any plugin has one. Only the length is checked. Storing the value needs the matching hosted service release; until then `trmnlp push` drops it, because it rewrites the local `settings.yml` from the server's response.
- `trmnlp push` now offers to delete the server-side transform script when the project has no local `transform.*` file. Previously, deleting the file locally was a silent no-op: the server kept executing its copy and every `trmnlp pull` re-created the file. Answering yes sends `serverless_language: none` in the pushed settings.yml, which the server consumes as an explicit removal request. `--force` pushes skip the question and behave exactly as before; a failed server check never blocks the push.

## 0.9.0

- Added OAuth2 support for local plugin preview (beta). Configure a provider with the flat `oauth_*` keys in `src/settings.yml` (authorize and token URLs, scopes, optional PKCE), which round-trip through `trmnlp push` and `pull`. Set `TRMNL_OAUTH_CLIENT_ID` and `TRMNL_OAUTH_CLIENT_SECRET` in your environment (credentials stay local and are never synced), and register `http://localhost:4567/oauth/callback` as the redirect URI in your OAuth app. `trmnlp serve` shows a Connect banner that runs the authorization code flow in the browser, stores the tokens in the cache directory (never in the project), and refreshes them before they expire. The access token is exposed to polling templates as `{{ oauth_access_token }}`, matching the hosted service. This is a beta feature; please report incorrect behaviour at https://github.com/usetrmnl/trmnlp/issues.

## 0.8.10

- Fixed Python serverless transforms failing on Windows. The local subprocess backend hardcoded `python3`, which the python.org Windows installer does not put on PATH (it installs `python` and the `py` launcher), so every Python transform raised "interpreter not available". The interpreter is now resolved from a per-language list of command candidates (`python3`, then `python`, then the `py` launcher) using a cross-platform PATH lookup, leaving POSIX behavior unchanged. (#116)

## 0.8.9

- Fixed `trmnlp serve` binding to localhost under Podman, which left the dev server unreachable through published ports. Container detection only looked for `/.dockerenv`, which Docker writes but Podman does not, so `serve` fell back to `127.0.0.1`. It now also checks for `/run/.containerenv`, which Podman writes, so the automatic `0.0.0.0` bind works for both runtimes. (#112)

## 0.8.8

- Added a `--server` flag to `trmnlp login` so commands like `trmnlp push` can target a self-hosted (BYOS) server. The chosen URL is saved as `base_url`, and the `user_` API key prefix is only required for trmnl.com; BYOS servers accept their own token formats. A scheme-less `--server` value (such as `localhost:3000`) no longer crashes the host check. (#113)
- `trmnlp list` now shows plugins with a nil `plugin_id`, which BYOS servers like LaraPaper return. (#113)

## 0.8.7

- Fixed `.trmnlp.yml` `variables` overrides under the `trmnl` namespace being dropped. The assembler re-applied the pre-override namespace after the transform, clobbering user overrides like `trmnl.user.time_zone`. (#110)
- Fixed the transform receiving the `trmnl.system` namespace, which the hosted service withholds. Transforms now see only `trmnl.user`, `trmnl.device`, and `trmnl.plugin_settings`, matching production.
- Added `trmnl.user.id` to the user namespace so its shape matches the hosted service.

## 0.8.6

- Fix missing form fields `db/data/form_fields.yml`.

## 0.8.5

- Fixed `pluralize`, `number_with_delimiter`, and `number_to_currency` Liquid filters raising `Liquid error: internal`. `trmnl-liquid` 0.7 moved `RailsHelpers` behind an opt-in `load(:rails)`, but the filters still probed `RailsHelpers.respond_to?` against the now-undefined constant. Stubbing an empty module makes the probe return false so the bundled fallback implementations run. (#105)

## 0.8.4

- Fixed `trmnlp serve` hanging after switching between browser tabs. Live reload now uses `rack.hijack` so SSE connections release their Puma worker thread immediately instead of holding it for the lifetime of the tab.
- Fixed Ctrl-C requiring three presses to stop the dev server. filewatcher 3.0.1 was clobbering Puma's signal handlers with its own `trap('INT') { exit }`.
- Fixed scaffolded plugins silently skipping their transform when `settings.yml` had `serverless_language: ''`. The empty string was treated as truthy in Ruby and short-circuited the file-extension fallback.
- Docker examples in the README now use `--pull always` (and `pull_policy: always` for Compose) so a new release is picked up on the next `docker run` without a manual pull.

## 0.8.3

- `trmnlp init` and `trmnlp clone` now scaffold a `.github/workflows/trmnl.yml` CI workflow and a `.gitignore`, and run `git init -b main`, so a cloned plugin is ready to push to GitHub and deploy on every commit to `main`
- Added `--skip-git` to `trmnlp init` and `trmnlp clone` for projects that manage Git themselves
- The Docker image now ships `git` so the `docker run trmnl/trmnlp clone` flow leaves a ready-to-push project on the host
- View templates now ship canonical `layout` + `title_bar` markup that passes `trmnlp lint`

## 0.8.2

- Fixed `framework_version: latest` rendering against the auto-upgrading `/latest/` asset path instead of the current concrete release, matching the hosted service (#99)
- Cleanup and minor improvements

## 0.8.1

### Added

- `trmnlp build --png` renders a PNG for every view alongside the HTML, with `--width`, `--height`, and `--color-depth` flags to override the defaults (#92)
- Colour-coded the preview's payload-size badge — yellow from 75 KB, red from 100 KB — so an oversized merge-variable payload is visible at a glance (#67)
- Added colour to CLI output — `lint` results, warnings, and errors — suppressed automatically when output is piped or redirected (#33)

### Fixed

- `trmnlp init` no longer produces read-only project files when trmnlp itself is installed read-only, such as on NixOS (#83)
- Non-JSON polling responses (`text/html`, `text/plain`) are exposed to templates as `{{ data }}`, matching the hosted service — previously `{{ text }}` (#81)

### Housekeeping

- Added SimpleCov coverage tracking, gated in CI at a 90% floor, plus dedicated specs for every lint check
- Extracted the headless-Firefox driver into a shared `FirefoxDriver` module used by both `serve` and `build --png`

## 0.8.0

### Housekeeping

- Upgraded the development, CI, and Docker baseline to Ruby 4.0.4
- Replaced the faye-websocket live reload with server-sent events, removing the eventmachine dependency
- Upgraded `filewatcher` to 3.x for Ruby 4.0 support
- Upgraded `mini_magick` to 5.x (ImageMagick 7 only)
- Upgraded `rubyzip` to 3.x
- Upgraded `puma` to 8.x
- Upgraded `oj` and `selenium-webdriver` to their latest releases
- Upgraded `trmnl-liquid` to 0.7 and `xdg` to 10
- Added the `cgi` gem, removed from Ruby's standard library in 4.0
- Dropped the redundant `pathname` gem dependency; Ruby provides `Pathname` built in
- Added `.rspec` configuration and a `Rakefile`

### Refactor

- Refactored screen generation into focused objects: `Screen`, `Screenshot`, `Renderer`, `ImageQuantizer`, `BrowserPool`, `Reporter`, `Watcher`, `Poller`, `UserDataAssembler`
- Added support for `text/html` and `text/plain` polling responses with JSON body sniffing (#81)
- Fixed Liquid conditionals (`{% if %}...{% endif %}`) spanning `polling_headers` values (#79)
- Fixed multi-select custom_fields being coerced into JSON strings — arrays now preserved (#80)
- Fixed `trmnl.device.{width,height}` in user-data so they reflect the picker's selected model (#94)
- Fixed `Permission denied` from `trmnlp clone` on Linux when overwriting template files (#83)
- Fixed deprecated `convert` warning by switching to mini_magick's `Magick` tool (#89)

### Serverless Transforms

- Added `transform_runtime:` config in `.trmnlp.yml` — serverless transforms are enabled by default and run whenever a `src/transform.*` file is present; set to `disabled` to turn them off
- Added `serverless_daemon_url:` override for pointing at a remote transform daemon (production-fidelity testing, shared team daemons)
- Added `serverless_language:` override (`python`, `ruby`, `php`, `node`)
- Added detection of `src/transform.{py,rb,php,js}` with language inferred from extension
- Added `TRMNLP::TransformClient` strategy host that selects `TransformBackend::Subprocess` (default) or `TransformBackend::Http` (when `serverless_daemon_url` is set) via `.from_config`
- Added `TRMNLP::TransformBackend::Subprocess` — local subprocess execution mirroring the hosted serverless wrapper contract verbatim, output flows back via a per-execution tempfile
- Added `python3`, `nodejs`, and `php-cli` to the main `Dockerfile`'s runtime stage alongside the existing `ruby` so all four supported transform languages work out of the box — no sidecar required
- Added transform-error surfacing in the preview UI when execution fails
- Added filewatcher re-poll when transform source changes (hot reload)
- Added `examples/hn-stories/` — a complete worked example fetching Hacker News top stories and rendering across all four sizes

### Framework Picker

- Added `framework_version:` plugin setting in `src/settings.yml` (defaults to `latest`, supports pinning to any released version) — round-trips through `trmnlp push`/`pull` alongside the hosted plugin archive format
- Added `framework_asset_host:` override in `.trmnlp.yml` for offline / mirrored development
- Added `TRMNLP::FrameworkVersion` mirroring the hosted framework versioning
- Added `rake framework:sync` to refresh `db/data/framework_versions.yml` from a local design-system checkout
- Updated `render_html.erb` to derive CSS/JS URLs from the resolved framework version

### FormField & Init Template

- Added FormField schema vendored from the hosted service (`db/data/form_fields.yml`) covering the full field-type allowlist
- Refreshed the `trmnlp init` template to scaffold `framework_version` and transform configuration, including a `transform.py.example`
- Fixed non-portable `/bin/bash` shebang in the generated `bin/trmnlp` (#78)

## 0.7.0

- Switch from Puppeteer + CDP to Selenium + WebDriver BiDi (@SorceressLyra)

## 0.6.1

- Update trmnl-liquid to 0.4.0

## 0.6.0

- Drop trmnl-component in lieu of plain iframe
- Add [trmnl-picker](https://github.com/usetrmnl/trmnl-picker) to support new TRMNL and BYOD screens
- Fix mashup layout previews

## 0.5.10

- Fix interpolation of multi-line polling URLs with custom fields

## 0.5.9

- Add `pathname` dependency

## 0.5.8

- Improve Docker commands in `bin/trmnlp` (@jrand0m, @jbarreiros)

## 0.5.7

- Use the `trmnl-liquid` gem so tags and filters stay up-to-date with the hosted offering

## 0.5.6

- Fixed bug that left blank plugins on server after upload failed
- Fixed bug creating upload.zip after previous upload had failed
- Added support to read API key fromk `TRMNL_API_KEY` environment variable (@andi4000)
- Fixed `init` command in Docker container (@jbarreiros)
- Automatically remove ephemeral Docker container after exit (@andi4000)

## 0.5.5

- Added dark mode (@stephenyeargin)
- Added override for `polling_url` in project config (@heroheman)
- Reworked `bin/dev` into more generic `bin/trmnlp`
- Fixed pull, push, and clone commands on Windows (@eugenio)

## 0.5.4

- Added `shared.liquid` file to template (@mariovisic)
- Stringified custom field values to match production (@mariovisic)
- Optimized image generation (@sd416)
- Fixed preview from growing when JSON data becomes too wide (@stephenyeargin)

## 0.5.3

- Added support for [reusable markup](https://docs.trmnl.com/go/reusing-markup) in `shared.liquid`
- Replaced custom case images with [\<trmnl-frame\> component](https://github.com/usetrmnl/trmnl-component)
- Updated custom Liquid filters
- Added API key validation during `trmnlp login`

## 0.5.2

- Added `time_zone` project config option, which is injected into `trmnl.user` variables
- Fixed time zone to always be UTC, matching trmnl.com servers (#38)

## 0.5.1

- Fixed `trmnl init`

## 0.5.0

- Added `trmlnp init` command
- Added `trmnlp clone` command
- Improved `trmnlp push` to create remote plugin on first publish
- Changed syntax of `trmnlp push` and `trmnlp pull` commands
- Added `oj` gem for JSON parsing (#32)

## 0.4.0

### Plugin Migration Strategy

The plugin directory structure has changed to better align with the [plugin archive format](https://help.trmnl.com/en/articles/10542599-importing-and-exporting-private-plugins#h_581fb988f0). 

Here is a migration strategy for existing plugin repositories:

1. Create `.trmnlp.yml` and bring over preview settings from `config.toml` - [see README](README.md)
2. Rename directory `views/` to `src/`
3. Create `src/settings.yml` and bring over plugin settings from `config.toml` - [see TRMNL docs](https://help.trmnl.com/en/articles/10542599-importing-and-exporting-private-plugins#h_581fb988f0)
4. Delete `config.toml`

### Changes

- Change plugin directory structure (see README for details)
- Add `login`, `push`, and `pull` commands
- Bring up-to-date with latest private plugin features:
  - Add `static` strategy
  - Add polling features: multiple URLs, new verbs, and request body
  - Add settings `dark_mode`, `no_screen_padding`, `custom_fields`
  - Add interpolation of custom fields in `polling\_\*` options
  - Add `{{ trmnl }}` variables 
- Add `watch` config
- Add interpolation of environment variables in `.trmnlp.yml` via `{{ env }}`
- Add auto-reload when `.trmnlp.yml` or `settings.yml` changes
- Add variable display
- Fix crash when #poll_data fails (#12)
- Fix git runtime error in Docker container (#12)



## 0.3.2

- Add bitmap rendering
- Add TRMNL's [custom plugin filters](https://help.trmnl.com/en/articles/10347358-custom-plugin-filters)
- Add support for user-supplied custom filters

## 0.3.1

- Add live render

## 0.3.0

- Add poll button
- Add case image overlays
- Add `trmnlp build` command
- Add support for `url` pointing to a local JSON data file

## 0.2.0

- Add "commands" concept to `trmnlp` executable
- `trmnlp serve` improvements
  - Add argument for plugin directory
  - Add options `-b` and `-p` for host bind and port, respectively
- Add Dockerfile

## 0.1.2

- Initial working release
