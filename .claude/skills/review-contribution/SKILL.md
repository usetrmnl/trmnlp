---
name: review-contribution
description: Review an outside contribution to trmnlp (a PR or an issue) from first principles — is the problem real, is this the smallest correct fix, does it keep parity with core — and prove each claim with a real render before merging, asking for changes, superseding or closing. Use when asked to review, verify, triage or merge someone's trmnlp PR or issue.
---

# Reviewing a contribution

## For each PR

1. **Is the problem real?** Reproduce it on `main` yourself, with a tiny plugin and a real Firefox. A claimed number (seconds saved, pixels cut) is measured again here, never copied.
2. **Does it belong in trmnlp?** Check core (`core-parity` skill). A change that makes trmnlp differ from core needs a reason and a line in the docs.
3. **Is it the smallest fix?** Prefer fixing a noisy check over adding an option to silence it. Prefer an existing tool (RSpec, `parallel_tests`) over new machinery.
4. **Prove it, then try to break it:**
   - check out `refs/pull/<n>/head` in its own worktree
   - run its specs and the full suite
   - revert the fix and watch the new spec fail
   - hunt the edge cases its spec does not cover, and look at the PNG
5. **Decide:** merge, merge after changes, supersede, or close.

## Acting on the decision

- Code changes on someone's branch are fine when they allow maintainer edits. Their words are not: never edit their PR title, body, commit messages or changelog lines. A wrong claim gets a comment with the measured number.
- A rework that changes what the PR is becomes a new PR of ours that credits them; close theirs with a link.
- Closing: thank them, give the evidence in a few lines, and say what smaller change would be accepted.
- Squash-merge rewrites the PR title into `main`'s history, so make sure the title is true first. Ask the author to fix it, or supersede.
- Merging several PRs in a row: each one conflicts on `CHANGELOG.md`'s `## Unreleased`. Rebase, keep both lines, wait for CI, merge, then the next.
