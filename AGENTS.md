# AGENTS.md

trmnlp is the local toolkit for TRMNL plugins: `serve`, `build`, `lint`, `test`, `init`, `push`/`pull`. It renders a plugin the way TRMNL core does, so a plugin that looks right here looks right on a device.

## Parity with TRMNL core comes first

- Core is the reference. When trmnlp and core disagree, trmnlp is wrong unless the difference is written down (README, `docs/testing.md`).
- Before changing how a page is built, rendered, captured or quantized, read what core does (repo `usetrmnl/core`, `lib/converter/`, `app/views/plugins/`, `config/initializers/`). The `core-parity` skill has the map.
- A behavior that exists only to make tests faster must not change what a plugin sees. Example: `trmnlp test` opens pages from a local address, and two Firefox prefs keep storage, cookies and the Referer as they are on `about:blank`.

## Keep it small

- No options for what can be fixed properly. A check that is noisy gets fixed or removed, not given `tolerance:` or `ignore:`.
- One concern per PR. Work found on the way gets its own PR off `main`.
- Delete code left with no caller in the same PR.

## Running it

- Ruby from `.ruby-version` (via mise or similar). `bundle install`, then `bundle exec bin/trmnlp <command>` from `lib/`.
- Specs: `bundle exec rspec` (about 1–2 minutes). Many specs drive a real Firefox, so Firefox must be installed. Also needed: `libfaketime`, `imagemagick` (7), `zbar`, Node 24, PHP and Python for the transform specs. CI installs them in `.github/workflows/ci.yaml`.
- `bundle exec rubocop` must be clean.
- On macOS, a stale `/etc/resolver/test` (left by puma-dev) makes every `*.test` lookup hang, and the suite stalls in `OutboundRequest` specs.
- Never kill processes by pattern (`pkill -f firefox`); other runs share the machine.

## Specs

- Write the failing spec first, then fix. Revert the fix once and watch the spec fail.
- Browser behavior is proven with a real Firefox render, not a double. Look at the PNG when a spec claims what the device shows.
- One expectation per example. A spec that depends on timing compares two clocks in the same page, never a fixed number of milliseconds.

## Changelog, commits and PRs

- Every user-visible change adds one line under `## Unreleased` at the top of `CHANGELOG.md`. Changelog conflicts between PRs are normal: keep both lines.
- Commit subjects are past tense and start with Added, Updated, Fixed, Removed or Refactored. The subject says what; the body says why.
- PR bodies: plain sentences and bullets, no headings, only what the change does.
- PRs are squash-merged, so the PR title becomes the commit on `main`. Check the title is accurate before merging.
- Releases: the `release` skill.

## Other people's work

- Never edit text someone else wrote: their PR title, PR body, commit messages, changelog lines or comments. Correct a claim with a comment, or open a superseding PR that credits them.
- Reviewing a contribution: the `review-contribution` skill.
