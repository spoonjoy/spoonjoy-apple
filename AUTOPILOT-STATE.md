# Spoonjoy Native Cover Normalization N2 Autopilot State

## Active N2 Item

- Repo: `/Users/arimendelow/Projects/spoonjoy-apple`
- Active worktree: `/Users/arimendelow/Projects/spoonjoy-apple-native-cover-normalization`
- Active branch: `worker/native-cover-normalization-n2`
- Host: `ouroboros-host` / user: `arimendelow` / cwd: `/Users/arimendelow/Projects/spoonjoy-apple-native-cover-normalization` / OS: `Darwin` / probed: 2026-07-15 19:56 -0700
- Doing doc: `worker/tasks/2026-07-15-1956-doing-native-cover-normalization-n2.md`
- Artifact root: `artifacts/apple/native-cover-normalization-n2/`
- Current phase: Unit 4b implementation complete; starting Unit 4c verification
- Scope guard: no web worktree edits, no `clem-feedback` worktree edits, no production mutation, no TestFlight publishing, no mutation single-flight or Photo Studio UI work.

## Historical Full Moon Context

## Exit Condition

This run is complete only when:

- Stale Spoonjoy Apple worktrees are retired and `/Users/arimendelow/Projects/spoonjoy-apple` is the clean canonical `main` checkout.
- The full-moon implementation branch is merged to `main`, pushed, and no stale branch/worktree from this run remains.
- Native validation passes: Swift tests, scenario verifier, app bundle, coverage, design/accessibility contract, screenshot route matrix, iOS simulator smoke, and macOS smoke.
- UI changes have fresh iOS and macOS screenshot evidence with valid `design-review.json` or valid `design-review-blocked.json`, app-emitted accessibility proofs, and a closed absurdity ledger.
- Latest TestFlight feedback/screenshots/crashes/telemetry are reconciled before publishing.
- A new internal TestFlight build is uploaded, processed `VALID`, attached to `Spoonjoy Internal`, verified with nonzero tester count, and build beta detail `internalBuildState=IN_BETA_TESTING`.
- TestFlight feedback autopilot transparency is improved or explicitly proven already sufficient.
- A durable continuation scan finds no ready native app work left under this mandate.

## Current Item

- Repo: `/Users/arimendelow/Projects/spoonjoy-apple`
- Canonical checkout: `/Users/arimendelow/Projects/spoonjoy-apple` on `main` at `2f6c3df`
- Active worktree: `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon`
- Active branch: `codex-native/native-full-moon`
- Host: `ouroboros-host` / user: `arimendelow` / cwd: `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon` / OS: `Darwin` / probed: 2026-07-09
- Planning doc: `codex-native/tasks/2026-07-09-1243-planning-native-full-moon.md`
- Doing doc: `codex-native/tasks/2026-07-09-1243-doing-native-full-moon.md`
- Current phase: Unit 0d complete; next executable unit is Unit 0e feedback listener path repair

## Terminal Evidence

- Stale linked worktrees retired on 2026-07-09.
- Only `/Users/arimendelow/Projects/spoonjoy-apple` and `/Users/arimendelow/Projects/spoonjoy-apple-native-full-moon` remain in `git worktree list`.
- Two named stashes preserve dirty stale-worktree changes:
  - `retire stale worktree codex-native/testflight-nav-paths 2026-07-09`
  - `retire stale worktree codex-native/testflight-cook-mode-checklists 2026-07-09`
- Planning reviewer Round 2 converged after fixes for iOS/macOS baseline, fail-closed design evidence, TestFlight verification, and route matrix scope.
- Unit 0a committed repo/worktree hygiene evidence at `aff517e8`.
- Unit 0b committed TestFlight feedback and telemetry intake at `df4a8d06`: no actionable unhandled feedback, latest valid iOS TestFlight build `1.0 (27)`, app id `6787505444`, group `31d60f58-aef9-4d44-b047-3a1f0dc61b5e`, and launchd listener/tunnel/reconcile services still pointing at retired `/Users/arimendelow/Projects/spoonjoy-apple-cookmode-ui-pass`.
- Unit 0c committed baseline screenshot evidence at `acc450ec`: five routes captured and design-reviewed (`recipes`, `recipe-detail`, `cook-mode`, `cookbooks`, `search`); `kitchen`, `shopping-list`, and `capture` exposed harness failures that did not emit terminal blocker artifacts. `absurdity-ledger.md` now tracks the shell/taste issues and harness gaps.

## Next Action

Execute Unit 0e from canonical `/Users/arimendelow/Projects/spoonjoy-apple`: run before/after `scripts/testflight-feedback-autopilot.mjs doctor`, repair installed launchd service paths with `scripts/testflight-feedback-autopilot.mjs install-launchd`, and save health/status logs under `unit-0e-*`. Unit 0f must then re-run status/doctor/reconcile dry-run before Unit 1 starts.

## Continuation Scan

| candidate | classification | evidence | disposition |
| --- | --- | --- | --- |
| Create doing doc and begin Unit 0 | ready | Planning doc approved; user delegated control; work-planner/work-doer skills read | Start now |
| Fix screenshot matrix hang | ready | Unit 0c hung while capturing `capture`; `kitchen` and `shopping-list` failed without `design-review-blocked.json`; matrix timeout was masked by `tee` | Units 1a-1f |
| Route-by-route taste/product audit | ready | Current screenshots show system blue, heavy dock, loud banners, placeholder labels | Units 1-4 |
| TestFlight feedback transparency and launchd path repair | ready | Autopilot status has many `fixed_unconfirmed` records, user reported opacity, and Unit 0b `doctor` points services at retired worktree | Units 0e-0f and later transparency units |

## Stop Condition

Not stopped. Ready work remains.
