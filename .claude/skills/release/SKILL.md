---
name: release
description: Release a new trmnlp version — bump lib/trmnlp/version.rb, move the CHANGELOG's Unreleased lines under the version, open the bump PR, and check the gem and Docker image published after merge. Use when asked to release, cut a version, bump the version, or publish trmnlp.
---

# Releasing trmnlp

Merging a change to `lib/trmnlp/version.rb` on `main` runs `.github/workflows/release.yaml`. It runs CI, tags `vX.Y.Z`, publishes the gem to RubyGems and pushes the `trmnl/trmnlp` image for amd64 and arm64. Each step skips what already exists, so a failed release can be re-run.

1. Pick the version from `## Unreleased` in `CHANGELOG.md`: a fix only is a patch (0.19.0 → 0.19.1); anything added or changed for plugin authors is a minor (0.19.0 → 0.20.0).
2. On a branch off `origin/main`:
   - set `VERSION` in `lib/trmnlp/version.rb`
   - `bundle install` so `Gemfile.lock` carries the new version
   - rename `## Unreleased` to `## X.Y.Z` (no new empty Unreleased heading; the next PR adds one)
3. Commit `Updated the version to X.Y.Z`, open the PR with that title and no body beyond the version, merge it once CI is green.
4. After merge, check it landed:
   - `gh run list -R usetrmnl/trmnlp --workflow release.yaml --limit 1` is green
   - `gem list trmnlp --remote --exact` shows X.Y.Z
   - `docker manifest inspect trmnl/trmnlp:X.Y.Z` lists both architectures

Past bumps to copy: `git log --oneline -- lib/trmnlp/version.rb`.
